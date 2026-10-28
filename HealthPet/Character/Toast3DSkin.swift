import SwiftUI
import SceneKit
import PetCore

/// v2 character 「面包人」 in 3D. The model is a part-split rigid rig (body, two arms, two
/// legs) baked by tools/export_toast_rig.py into Resources/Models, with three clips:
/// `idle`, `happy` and `bow`. Breathing, floating, waving and the pat hop are driven from
/// code on top of those so they can follow mood.
struct Toast3DSkin: CharacterSkin {
    let id = "toast-3d"
    let displayName = "Toast"

    func makeView(state: PetState, reactions: Int) -> AnyView {
        AnyView(Toast3DView(state: state, reactions: reactions))
    }

    func greeting(for state: PetState) -> String {
        ToastSkin().greeting(for: state)
    }
}

private struct Toast3DView: View {
    let state: PetState
    let reactions: Int

    var body: some View {
        ToastSceneView(state: state, reactions: reactions)
            .saturation(state.isAsleep ? 0.6 : 1)
            .overlay(alignment: .topTrailing) {
                if state.isAsleep {
                    Text("z z z")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Toast, feeling \(state.mood.rawValue)")
    }
}

private struct ToastSceneView: UIViewRepresentable {
    let state: PetState
    let reactions: Int

    func makeCoordinator() -> ToastRig { ToastRig() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.isPlaying = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(state: state, reactions: reactions)
    }
}

// MARK: - Rig

/// Owns the SceneKit scene. Node layering, outermost first:
/// `hop` (pat jump) → `float` (idle drift) → `breathe` (squash at the feet) → model,
/// and inside the model, per part: clip-driven bone → `wave` node → mesh.
final class ToastRig {
    let scene = SCNScene()
    let camera = SCNNode()

    private let hop = SCNNode()
    private let float = SCNNode()
    private let breathe = SCNNode()
    private let keyLight = SCNNode()
    private let waveTimer = SCNNode()

    private var model: SCNNode?
    private var clips: [String: SCNAnimationPlayer] = [:]
    /// Per part: the extra node under the clip-driven bone, used for code waves.
    private var waveNodes: [String: SCNNode] = [:]
    private var state: PetState?
    private var reactions: Int?
    private var busyUntil = Date.distantPast

    /// The rig's toast faces +X; this turns it towards the camera with a slight angle.
    private static let facing = Float(-90 - 12).degreesToRadians
    private static let wavingArm = "armR"
    /// Sign of the rotation about the facing axis that lifts `wavingArm` outward.
    private static let liftDirection: Float = -1

    /// Model height in scene units after normalising.
    private let height: Float = 1

    init() {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = Self.environmentImage()
        scene.lightingEnvironment.intensity = 1.4

        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 28
        camera.camera?.zNear = 0.1
        // Frame the toast plus headroom for the hop.
        let centerY = height * 0.58
        let distance = (height * 0.68) / tan(Float(14).degreesToRadians)
        camera.simdPosition = SIMD3(0, centerY, distance)
        camera.simdLook(at: SIMD3(0, centerY, 0))
        scene.rootNode.addChildNode(camera)

        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 900
        keyLight.light?.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        keyLight.simdEulerAngles = SIMD3(-0.6, -0.5, 0)
        scene.rootNode.addChildNode(keyLight)

        scene.rootNode.addChildNode(hop)
        hop.addChildNode(float)
        float.addChildNode(breathe)
        scene.rootNode.addChildNode(waveTimer)

        load()
    }

    // MARK: Loading

    private func load() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let rig = try? ToastRigFile.load() else { return }
            DispatchQueue.main.async { self?.install(rig) }
        }
    }

    private func install(_ rig: ToastRigFile) {
        let model = SCNNode()
        for (name, geometry) in rig.geometries {
            let pose = SCNNode()
            pose.name = "toast_\(name)"
            pose.simdPosition = rig.rest[name]!.position
            pose.simdOrientation = rig.rest[name]!.orientation
            let wave = SCNNode()
            wave.addChildNode(SCNNode(geometry: geometry))
            pose.addChildNode(wave)
            model.addChildNode(pose)
            waveNodes[name] = wave
        }

        // Normalise: feet on y = 0, centred, `height` tall, face turned slightly to the side.
        let (lo, hi) = model.boundingBox
        let scale = height / Float(hi.y - lo.y)
        model.simdScale = SIMD3(repeating: scale)
        model.simdPosition = SIMD3(-Float(lo.x + hi.x) / 2 * scale, -Float(lo.y) * scale, -Float(lo.z + hi.z) / 2 * scale)
        let turn = SCNNode()
        turn.simdEulerAngles.y = Self.facing
        turn.addChildNode(model)
        breathe.addChildNode(turn)
        self.model = model

        for (name, clip) in rig.clips {
            let player = SCNAnimationPlayer(animation: SCNAnimation(caAnimation: clip))
            player.stop()
            model.addAnimationPlayer(player, forKey: name)
            clips[name] = player
        }
        if let idle = clips["idle"] {
            idle.animation.repeatCount = .infinity
            idle.play()
        }
        for name in ["happy", "bow"] {
            guard let player = clips[name] else { continue }
            player.animation.repeatCount = 1
            player.animation.blendInDuration = 0.3
            player.animation.blendOutDuration = 0.4
        }

        if let state { applyMood(state) }
        if state?.isAsleep != true { play("bow", speed: 1.6) }  // a little hello
    }

    // MARK: State

    func update(state: PetState, reactions: Int) {
        if state != self.state {
            self.state = state
            applyMood(state)
        }
        if let last = self.reactions, reactions > last { pat() }
        self.reactions = reactions
    }

    /// Idle tempo and drift follow mood: lively when golden or fresh, slow when soggy,
    /// still and dim while asleep.
    private func applyMood(_ state: PetState) {
        let tempo: Double
        switch state.mood {
        case .golden, .fresh: tempo = 1
        case .burnt: tempo = 0.8
        case .soggy: tempo = 0.6
        }
        let asleep = state.isAsleep
        clips["idle"]?.speed = asleep ? 0.3 : CGFloat(tempo)
        keyLight.light?.intensity = asleep ? 350 : 900
        scene.lightingEnvironment.intensity = asleep ? 0.9 : 1.4

        // Breathe: a soft squash anchored at the feet.
        breathe.removeAllActions()
        let breathTime = (asleep ? 4.0 : 3.0) / tempo
        let inhale = SCNAction.customAction(duration: breathTime) { node, t in
            let phase = sin(Float(t) / Float(breathTime) * 2 * .pi)
            let amount: Float = asleep ? 0.035 : 0.02
            node.simdScale = SIMD3(1 - amount * 0.5 * phase, 1 + amount * phase, 1 - amount * 0.5 * phase)
        }
        breathe.runAction(.repeatForever(inhale))

        // Float: a slow bob; settles on the ground while asleep.
        float.removeAllActions()
        float.simdPosition = .zero
        if !asleep {
            let rise = Float(tempo >= 1 ? 0.04 : 0.025) * height
            let up = SCNAction.moveBy(x: 0, y: CGFloat(rise), z: 0, duration: 1.4 / tempo)
            up.timingMode = .easeInEaseOut
            float.runAction(.repeatForever(.sequence([up, up.reversed()])))
        }

        // Wave now and then, more often when in a good mood.
        waveTimer.removeAllActions()
        if !asleep {
            let wait = SCNAction.wait(duration: 10 / tempo, withRange: 6)
            let wave = SCNAction.run { [weak self] _ in DispatchQueue.main.async { self?.wave() } }
            waveTimer.runAction(.repeatForever(.sequence([wait, wave])))
        }
    }

    // MARK: Reactions

    private func pat() {
        let jump = SCNAction.moveBy(x: 0, y: CGFloat(height * 0.18), z: 0, duration: 0.18)
        jump.timingMode = .easeOut
        let land = SCNAction.moveBy(x: 0, y: CGFloat(-height * 0.18), z: 0, duration: 0.22)
        land.timingMode = .easeIn
        hop.removeAllActions()
        hop.simdPosition = .zero
        hop.runAction(.sequence([jump, land]))
        play("happy", speed: 1.2)
    }

    private func play(_ name: String, speed: CGFloat) {
        guard let player = clips[name] else { return }
        clips.forEach { if $0.key != "idle" { $0.value.stop(withBlendOutDuration: 0.2) } }
        player.speed = speed
        player.play()
        busyUntil = Date() + player.animation.duration / Double(speed)
    }

    /// Lifts the right arm out to the side and swings it, on its own node so it layers
    /// over whatever clip is playing.
    private func wave() {
        guard let node = waveNodes[Self.wavingArm], let bone = node.parent, Date() > busyUntil else { return }
        let duration = 2.0
        let action = SCNAction.customAction(duration: duration) { node, elapsed in
            let t = Float(elapsed) / Float(duration)
            let lift = min(1, min(t, 1 - t) * 5)               // ease up, hold, ease down
            let swing = sin(t * 3 * 2 * .pi) * 0.3 * lift       // three waves
            // Out to the side and up (about the facing axis), then a little towards the camera
            // so the hand clears the edge of the slice.
            let side = simd_quatf(angle: Self.liftDirection * (2.9 * lift + swing), axis: SIMD3(1, 0, 0))
            let forward = simd_quatf(angle: -Self.liftDirection * 0.7 * lift, axis: SIMD3(0, 1, 0))
            let raise = forward * side
            // The swing is in model space; express it in the bone's current (clip-driven) frame.
            let pose = bone.presentation.simdOrientation
            node.simdOrientation = pose.inverse * raise * pose
        }
        node.removeAllActions()
        node.runAction(action) { node.simdOrientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        busyUntil = Date() + duration
    }

    /// A soft warm studio gradient so the PBR materials have something to reflect.
    private static func environmentImage() -> UIImage {
        let size = CGSize(width: 64, height: 32)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 1, green: 0.98, blue: 0.94, alpha: 1).cgColor,
                          UIColor(red: 0.98, green: 0.9, blue: 0.78, alpha: 1).cgColor,
                          UIColor(red: 0.55, green: 0.45, blue: 0.38, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                      locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
}

// MARK: - Rig file

/// Reads toast_rig.json / toast_rig.bin and the textures written by tools/export_toast_rig.py.
private struct ToastRigFile {
    struct Pose { var position: SIMD3<Float>; var orientation: simd_quatf }

    var geometries: [(String, SCNGeometry)] = []
    var rest: [String: Pose] = [:]
    var clips: [String: CAAnimation] = [:]

    private struct JSON: Decodable {
        struct Part: Decodable { let vertexOffset, vertexCount, indexOffset, indexCount: Int }
        let fps: Double
        let parts: [String: Part]
        let rest: [String: [Float]]
        let clips: [String: [String: [[Float]]]]
    }

    static func load() throws -> ToastRigFile {
        func url(_ name: String, _ ext: String) throws -> URL {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw CocoaError(.fileNoSuchFile) }
            return url
        }
        let json = try JSONDecoder().decode(JSON.self, from: Data(contentsOf: url("toast_rig", "json")))
        let blob = try Data(contentsOf: url("toast_rig", "bin"))

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIImage(contentsOfFile: try url("toast_color", "jpg").path)
        material.normal.contents = UIImage(contentsOfFile: try url("toast_normal", "png").path)
        let orm = UIImage(contentsOfFile: try url("toast_orm", "jpg").path)
        material.ambientOcclusion.contents = orm
        material.ambientOcclusion.textureComponents = .red
        material.roughness.contents = orm
        material.roughness.textureComponents = .green
        // Soft vinyl: nothing is metal. The ORM metal channel made the glossy eyes mirror the sky.
        material.metalness.contents = 0.0

        var file = ToastRigFile()
        let stride = 12 * MemoryLayout<Float>.size
        for (name, part) in json.parts.sorted(by: { $0.key < $1.key }) {
            let vertices = blob.subdata(in: part.vertexOffset ..< part.vertexOffset + part.vertexCount * stride)
            func source(_ semantic: SCNGeometrySource.Semantic, components: Int, offset: Int) -> SCNGeometrySource {
                SCNGeometrySource(data: vertices, semantic: semantic, vectorCount: part.vertexCount,
                                  usesFloatComponents: true, componentsPerVector: components,
                                  bytesPerComponent: MemoryLayout<Float>.size,
                                  dataOffset: offset * MemoryLayout<Float>.size, dataStride: stride)
            }
            let indices = blob.subdata(in: part.indexOffset ..< part.indexOffset + part.indexCount * 4)
            let element = SCNGeometryElement(data: indices, primitiveType: .triangles,
                                             primitiveCount: part.indexCount / 3, bytesPerIndex: 4)
            let geometry = SCNGeometry(sources: [source(.vertex, components: 3, offset: 0),
                                                 source(.normal, components: 3, offset: 3),
                                                 source(.texcoord, components: 2, offset: 6),
                                                 source(.tangent, components: 4, offset: 8)],
                                       elements: [element])
            geometry.materials = [material]
            file.geometries.append((name, geometry))
        }

        func pose(_ v: [Float]) -> Pose {
            Pose(position: SIMD3(v[0], v[1], v[2]), orientation: simd_quatf(ix: v[3], iy: v[4], iz: v[5], r: v[6]))
        }
        file.rest = json.rest.mapValues(pose)

        for (clip, tracks) in json.clips {
            let group = CAAnimationGroup()
            var animations: [CAAnimation] = []
            for (part, frames) in tracks {
                let duration = Double(frames.count - 1) / json.fps
                let position = CAKeyframeAnimation(keyPath: "/toast_\(part).position")
                position.values = frames.map { NSValue(scnVector3: SCNVector3($0[0], $0[1], $0[2])) }
                let orientation = CAKeyframeAnimation(keyPath: "/toast_\(part).orientation")
                orientation.values = frames.map { NSValue(scnVector4: SCNVector4($0[3], $0[4], $0[5], $0[6])) }
                for track in [position, orientation] {
                    track.duration = duration
                    animations.append(track)
                }
                group.duration = duration
            }
            group.animations = animations
            file.clips[clip] = group
        }
        return file
    }
}

private extension Float {
    var degreesToRadians: Float { self * .pi / 180 }
}
