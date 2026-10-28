import SwiftUI
import PetCore

/// The home screen is the pet's room: the pet on its cutting board, one friendly line,
/// and three big buttons. No health scores here on purpose; numbers live under "More".
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoomBackground(isNight: model.petState.isAsleep)

                VStack(spacing: 0) {
                    TopBar(daysTogether: model.daysTogether) { sheet = .settings }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer(minLength: 8)

                    SpeechBubble(text: model.skin.greeting(for: model.petState))
                        .padding(.horizontal, 40)

                    PetStage(height: min(geo.size.height * 0.5, 470))

                    BondBar(name: model.skin.displayName, bond: model.bond)
                        .padding(.top, 12)

                    Spacer(minLength: 16)

                    ActionRow(
                        canClaim: model.canClaimTreat,
                        onDressUp: { sheet = .dressUp },
                        onClaim: { model.claimTreat() },
                        onMemories: { sheet = .memories }
                    )
                    .padding(.horizontal, 16)

                    MoreHandle { sheet = .more }
                        .padding(.top, 14)
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .settings: SettingsView()
            case .memories: MemoriesView()
            case .more: MoreSheet(open: { self.sheet = $0 })
            case .dressUp: ComingSoonView(title: "Dress up", image: "ic_dressup",
                                          message: "Hats, bandanas and crumbs of style are on the way.")
            case .world: ComingSoonView(title: "World", image: "ic_world",
                                        message: "Soon your toast can visit friends' pets.")
            }
        }
    }
}

enum HomeSheet: String, Identifiable {
    case settings, memories, more, dressUp, world
    var id: String { rawValue }
}

// MARK: - Pet stage

/// The pet standing on its board, a speech bubble, the pat bubble and the toaster bed.
private struct PetStage: View {
    @Environment(AppModel.self) private var model
    let height: CGFloat

    @State private var bounce = false
    @State private var hearts: [FloatingHeart] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("pet_board")
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.82)
                .offset(y: -height * 0.02)

            model.skin.makeView(state: model.petState)
                .frame(height: height * 0.66)
                .scaleEffect(bounce ? 1.08 : 1, anchor: .bottom)
                .offset(y: -height * 0.12)
                .onTapGesture { model.pat() }

            ForEach(hearts) { heart in
                Image("ic_heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28)
                    .offset(x: heart.x, y: heart.rise ? -height * 0.85 : -height * 0.5)
                    .opacity(heart.rise ? 0 : 1)
            }

            Image("ic_toaster")
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.22)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .offset(y: -height * 0.06)
                .accessibilityLabel("Toaster bed")
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            PatBubble { model.pat() }
                .padding(.leading, 24)
                .padding(.top, height * 0.22)
        }
        .onChange(of: model.reactionCount) { react() }
    }

    private func react() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce = false }
        }

        let heart = FloatingHeart(x: .random(in: -50...50))
        hearts.append(heart)
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.0)) {
                if let i = hearts.firstIndex(where: { $0.id == heart.id }) { hearts[i].rise = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            hearts.removeAll { $0.id == heart.id }
        }
    }
}

private struct FloatingHeart: Identifiable {
    let id = UUID()
    var x: CGFloat
    var rise = false
}

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.ink.opacity(0.08)))
            .contentTransition(.opacity)
            .animation(.default, value: text)
    }
}

/// Floating "pat me" bubble, like a little glass orb next to the pet.
private struct PatBubble: View {
    let action: () -> Void
    @State private var float = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.35))
                        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
                    VStack(spacing: 0) {
                        Image("ic_heart").resizable().scaledToFit().frame(width: 34)
                        Text("+\(AppModel.pointsPerPat)")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Palette.crust)
                    }
                }
                .frame(width: 64, height: 64)

                Text("Pat")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
        .offset(y: float ? -4 : 4)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: float)
        .onAppear { float = true }
        .accessibilityLabel("Pat your pet")
    }
}

// MARK: - Top bar & bond

private struct TopBar: View {
    let daysTogether: Int
    let onMenu: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Image("toast_golden")
                    .resizable()
                    .scaledToFit()
                    .padding(5)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.7)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Day \(daysTogether)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("together")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 18)
            .padding(.vertical, 6)
            .glass(Capsule())

            Spacer()

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .glass(Circle())
            }
            .accessibilityLabel("Settings")
        }
    }
}

private struct BondBar: View {
    let name: String
    let bond: Bond

    var body: some View {
        let progress = bond.progress
        VStack(spacing: 8) {
            Text(name)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.55))
                GeometryReader { geo in
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.honey, Palette.crust], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * CGFloat(progress.current) / CGFloat(max(progress.needed, 1)), 24))
                }
                Text("\(progress.current) / \(progress.needed)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 190, height: 22)
            .overlay(alignment: .leading) {
                Text("Lv \(bond.level)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Capsule().fill(Palette.crust))
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    .offset(x: -18)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Friendship level \(bond.level), \(progress.current) of \(progress.needed)")
        }
    }
}

// MARK: - Bottom actions

private struct ActionRow: View {
    let canClaim: Bool
    let onDressUp: () -> Void
    let onClaim: () -> Void
    let onMemories: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ActionCard(image: "ic_dressup", title: "Dress up", action: onDressUp)
                .frame(width: 104)

            Button(action: onClaim) {
                VStack(spacing: 4) {
                    Image("ic_claim")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 78)
                        .shadow(color: Palette.honey.opacity(canClaim ? 0.9 : 0), radius: 18)
                        .saturation(canClaim ? 1 : 0.3)
                        .offset(y: -26)
                        .padding(.bottom, -26)
                    Text(canClaim ? "Daily treat" : "See you tomorrow")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.ink.opacity(canClaim ? 0.85 : 0.5))
                    Text(canClaim ? "+\(AppModel.pointsPerTreat)" : "Claimed")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink.opacity(0.55))
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .glass(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(!canClaim)

            ActionCard(image: "ic_memories", title: "Memories", action: onMemories)
                .frame(width: 104)
        }
    }
}

private struct ActionCard: View {
    let image: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
                    .offset(y: -18)
                    .padding(.bottom, -18)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.85))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .glass(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

private struct MoreHandle: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up.circle.fill")
                Text("More")
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Palette.ink.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous)
                    .fill(.white.opacity(0.3))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView().environment(AppModel())
}
