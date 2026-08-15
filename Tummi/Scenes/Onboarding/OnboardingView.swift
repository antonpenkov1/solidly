import SwiftUI

final class OnboardingStore: ObservableObject, OnboardingDisplayLogic {
    @Published var errorText: String?
    @Published var didSave = false

    private var interactor: OnboardingBusinessLogic?

    init() {
        let presenter = OnboardingPresenter()
        interactor = OnboardingInteractor(presenter: presenter)
        presenter.view = self
    }

    func save(name: String, birthDate: Date, sex: ChildSex, gestationWeeks: Int, units: UnitSystem) {
        interactor?.save(request: .init(
            name: name, birthDate: birthDate, sex: sex,
            gestationWeeks: gestationWeeks, units: units
        ))
    }

    func display(viewModel: Onboarding.Save.ViewModel) {
        errorText = viewModel.errorText
        didSave = viewModel.didSave
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @StateObject private var store = OnboardingStore()
    @State private var page = 0
    @State private var name = ""
    @State private var birthDate = Date()
    @State private var sex: ChildSex = .girl
    @State private var isPreterm = false
    @State private var gestationWeeks = 40
    @State private var units: UnitSystem = Locale.current.measurementSystem == .us ? .imperial : .metric

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    childForm.tag(1)
                    tour.tag(2)
                    disclaimer.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Four unlabelled swipes with no sense of progress is its own small anxiety.
                HStack(spacing: 7) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.accent : Theme.hairline)
                            .frame(width: index == page ? 20 : 7, height: 7)
                            .animation(.easeOut(duration: 0.2), value: page)
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .keyboardDoneButton()
        .onChange(of: store.didSave) { _, saved in
            if saved { onFinish() }
        }
        .onAppear(perform: applyLaunchArguments)
    }

    // MARK: - Pages

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("Tummi")
                .font(Theme.serif(46, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Feeding your baby, with the reasoning attached.")
                .font(Theme.rounded(20, .medium))
                .foregroundStyle(Theme.ink)
            Text("Every recommendation in this app names the guideline or trial it comes from, so you can read it yourself — or take it to your paediatrician and disagree with it.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)

            VStack(alignment: .leading, spacing: 12) {
                bullet("book.closed", String(localized: "WHO, ESPGHAN, AAP, NIAID and the trials behind them"))
                bullet("scalemass", String(localized: "Track grams, millilitres, growth and allergen exposures"))
                bullet("stethoscope", String(localized: "Replace any number with the one your doctor gave you"))
                bullet("lock", String(localized: "Everything stays on this device"))
            }
            .padding(.top, 8)

            Spacer()
            primaryButton(String(localized: "Get started")) { page = 1 }
        }
        .padding(28)
    }

    private var childForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("About your baby")
                    .font(Theme.serif(32, .semibold))
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Name")
                    TextField(String(localized: "Optional"), text: $name)
                        .font(Theme.rounded(18, .medium))
                        .textFieldStyle(.plain)
                        .padding(.vertical, 10)
                    Hairline()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Date of birth")
                    DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Sex")
                    Picker("", selection: $sex) {
                        Text("Girl").tag(ChildSex.girl)
                        Text("Boy").tag(ChildSex.boy)
                    }
                    .pickerStyle(.segmented)
                    Text("Growth percentiles are read against different WHO curves for girls and boys.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $isPreterm) {
                        Text("Born before 37 weeks")
                            .font(Theme.rounded(16, .medium))
                    }
                    if isPreterm {
                        Stepper(value: $gestationWeeks, in: 24...36) {
                            Text("\(gestationWeeks) weeks at birth")
                                .font(Theme.rounded(15, .regular))
                        }
                        Text("Tummi will use corrected age for feeding milestones and growth charts, which is how they are meant to be read for preterm babies.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.faint)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Units")
                    Picker("", selection: $units) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }

                primaryButton(String(localized: "Continue")) { page = 2 }
                    .padding(.top, 8)
            }
            .padding(28)
        }
        .onChange(of: isPreterm) { _, preterm in
            gestationWeeks = preterm ? 34 : 40
        }
    }

    /// The five tabs, in one screen. Without this a new user meets five unlabelled ideas at
    /// once and has to reverse-engineer what the app is for from an empty Today screen.
    private var tour: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("How Tummi works")
                    .font(Theme.serif(32, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Five screens. You will mostly live on the first one.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)

                VStack(spacing: 0) {
                    tourRow("sun.max", String(localized: "Today"),
                            String(localized: "Log a feed in two taps and see how the day compares to the range for your baby's age."))
                    Hairline()
                    tourRow("list.bullet", String(localized: "Log"),
                            String(localized: "Everything you have recorded, newest first. Tap any entry to correct it."))
                    Hairline()
                    tourRow("carrot", String(localized: "Foods"),
                            String(localized: "148 foods: when each is usually introduced, whether it is an allergen, and exactly how to cut it."))
                    Hairline()
                    tourRow("checklist", String(localized: "Plan"),
                            String(localized: "What the guidance says at this stage, what is coming next — and where you enter your paediatrician's own numbers."))
                    Hairline()
                    tourRow("chart.xyaxis.line", String(localized: "Growth"),
                            String(localized: "Weight, length and head circumference on the real WHO curves."))
                }
                .cardStyle(padding: 0)

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("The green chips are links")
                            .font(Theme.rounded(15, .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Under every recommendation you will see something like “WHO, 2023”. Tap it and the actual guideline opens. Nothing in Tummi asks you to take its word for it.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accentSoft))

                primaryButton(String(localized: "Got it")) { page = 3 }
                    .padding(.top, 4)
            }
            .padding(28)
        }
    }

    private func tourRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.rounded(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var disclaimer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Before you start")
                    .font(Theme.serif(32, .semibold))
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 14) {
                    disclaimerRow(
                        "stethoscope",
                        String(localized: "Tummi is not a doctor"),
                        String(localized: "It summarises published guidance. It does not diagnose anything, and it cannot see your baby. Your paediatrician's advice takes priority over everything shown here — and you can enter their numbers so the app follows them instead.")
                    )
                    disclaimerRow(
                        "exclamationmark.triangle",
                        String(localized: "Amounts are ranges, not targets"),
                        String(localized: "Babies vary enormously day to day. Use the numbers to spot a trend over weeks, never to push a baby to finish a portion.")
                    )
                    disclaimerRow(
                        "phone",
                        String(localized: "When to call someone"),
                        String(localized: "Trouble breathing, a swollen face or lips, repeated vomiting after a food, blood in stool, or a baby who has stopped feeding — contact emergency services or your doctor, not an app.")
                    )
                    disclaimerRow(
                        "lock",
                        String(localized: "Your data stays here"),
                        String(localized: "Everything is stored on this device. Tummi has no account, no server and no analytics.")
                    )
                }

                if let errorText = store.errorText {
                    Text(errorText)
                        .font(Theme.rounded(14, .medium))
                        .foregroundStyle(Theme.clay)
                }

                primaryButton(String(localized: "I understand — start tracking")) {
                    store.save(name: name, birthDate: birthDate, sex: sex,
                               gestationWeeks: isPreterm ? gestationWeeks : 40, units: units)
                }
                .padding(.top, 8)
            }
            .padding(28)
        }
    }

    // MARK: - Pieces

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
        }
    }

    private func disclaimerRow(_ symbol: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(Theme.rounded(16, .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
        }
        .cardStyle()
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.rounded(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.accent))
                .foregroundStyle(Theme.bg)
        }
        .buttonStyle(.plain)
    }

    private func applyLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-OnboardingPage"), index + 1 < arguments.count,
           let requested = Int(arguments[index + 1]) {
            page = requested
        }
        #endif
    }
}
