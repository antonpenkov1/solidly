import Foundation

enum AgeStage: String, CaseIterable, Codable, Hashable {
    case milkOnly
    case gettingReady
    case firstTastes
    case buildingMeals
    case familyTable
    case toddler

    static func stage(forMonths months: Double) -> AgeStage {
        switch months {
        case ..<4: return .milkOnly
        case 4 ..< 6: return .gettingReady
        case 6 ..< 9: return .firstTastes
        case 9 ..< 12: return .buildingMeals
        case 12 ..< 24: return .familyTable
        default: return .toddler
        }
    }

    var monthRange: ClosedRange<Double> {
        switch self {
        case .milkOnly: return 0...4
        case .gettingReady: return 4...6
        case .firstTastes: return 6...9
        case .buildingMeals: return 9...12
        case .familyTable: return 12...24
        case .toddler: return 24...36
        }
    }

    var title: LocalizedText {
        switch self {
        case .milkOnly: return T("Milk only", "Только молоко")
        case .gettingReady: return T("Getting ready", "Готовимся")
        case .firstTastes: return T("First tastes", "Первые вкусы")
        case .buildingMeals: return T("Building meals", "Собираем приёмы пищи")
        case .familyTable: return T("The family table", "Общий стол")
        case .toddler: return T("Toddler eating", "Еда как у всех")
        }
    }

    var rangeLabel: LocalizedText {
        switch self {
        case .milkOnly: return T("0–4 months", "0–4 месяца")
        case .gettingReady: return T("4–6 months", "4–6 месяцев")
        case .firstTastes: return T("6–8 months", "6–8 месяцев")
        case .buildingMeals: return T("9–11 months", "9–11 месяцев")
        case .familyTable: return T("12–23 months", "12–23 месяца")
        case .toddler: return T("24 months and beyond", "24 месяца и старше")
        }
    }
}

/// The numbers Tummi shows as "today's target".
///
/// Ranges, never single numbers: every source that publishes an amount publishes a range,
/// and a baby who eats at the bottom of it is not behind. A range also makes it much
/// harder to read the app as a quota to hit.
struct FeedingTargets: Hashable {
    var milkFeedsPerDay: ClosedRange<Int>?
    var dailyMilkMl: ClosedRange<Double>?
    var mealsPerDay: ClosedRange<Int>?
    var snacksPerDay: ClosedRange<Int>?
    var perMealGrams: ClosedRange<Double>?
    var energyFromSolidsKcal: Int?
    /// Set when the family recorded their paediatrician's own numbers.
    var overriddenFields: Set<OverrideField> = []
    var attribution: String?
    var sourceIds: [String] = []

    enum OverrideField: String, Hashable {
        case dailyMilkMl
        case mealsPerDay
        case perMealGrams
    }

    var isOverridden: Bool { !overriddenFields.isEmpty }
}

struct GuidanceCard: Identifiable, Hashable {
    let id: String
    let title: LocalizedText
    let body: LocalizedText
    let sourceIds: [String]
}

struct StageProfile: Hashable {
    let stage: AgeStage
    let headline: LocalizedText
    let cards: [GuidanceCard]
}

enum Guidance {

    // MARK: - Targets

    /// Feeding targets for a child on a given day.
    ///
    /// - Parameters:
    ///   - weightKg: latest recorded weight, used for the millilitres-per-kilogram milk
    ///     guide. Without a weight the milk range is omitted rather than guessed.
    ///   - overrides: the family's paediatrician plan, which wins over published ranges.
    static func targets(
        forMonths months: Double,
        weightKg: Double?,
        overrides: [OverrideKey: CareOverride] = [:]
    ) -> FeedingTargets {
        var targets = baseTargets(forMonths: months, weightKg: weightKg)

        if let override = overrides[.dailyMilkMl] {
            targets.dailyMilkMl = override.value...override.value
            targets.overriddenFields.insert(.dailyMilkMl)
            targets.attribution = override.attribution
        }
        if let override = overrides[.mealsPerDay] {
            let meals = Int(override.value.rounded())
            targets.mealsPerDay = meals...meals
            targets.overriddenFields.insert(.mealsPerDay)
            targets.attribution = override.attribution
        }
        if let override = overrides[.perMealGrams] {
            targets.perMealGrams = override.value...override.value
            targets.overriddenFields.insert(.perMealGrams)
            targets.attribution = override.attribution
        }
        return targets
    }

    private static func baseTargets(forMonths months: Double, weightKg: Double?) -> FeedingTargets {
        // NHS: roughly 150–200 ml per kg per day for formula-fed babies until about 6 months.
        // Past 6 months solids take over part of the intake, so the guide steps down.
        let milkRange: ClosedRange<Double>? = weightKg.map { weight in
            switch months {
            case ..<6: return (weight * 150)...(weight * 200)
            case 6 ..< 9: return 500...800
            case 9 ..< 12: return 400...600
            default: return 350...500
            }
        } ?? {
            switch months {
            case ..<6: return nil
            case 6 ..< 9: return 500...800
            case 9 ..< 12: return 400...600
            default: return 350...500
            }
        }()

        switch AgeStage.stage(forMonths: months) {
        case .milkOnly:
            return FeedingTargets(
                milkFeedsPerDay: months < 1 ? 8...12 : 6...8,
                dailyMilkMl: milkRange,
                mealsPerDay: nil, snacksPerDay: nil, perMealGrams: nil,
                energyFromSolidsKcal: nil,
                sourceIds: ["nhs.weaning", "aap.infantfeeding", "who.cf2023"]
            )

        case .gettingReady:
            return FeedingTargets(
                milkFeedsPerDay: 5...8,
                dailyMilkMl: milkRange,
                mealsPerDay: nil, snacksPerDay: nil, perMealGrams: nil,
                energyFromSolidsKcal: nil,
                sourceIds: ["espghan.cf2017", "efsa.cf2019", "nhs.weaning"]
            )

        case .firstTastes:
            // WHO's portion ladder: 2–3 tablespoons (~30–45 g) at 6 months, reaching
            // half a 250 ml cup (~125 g) by 9 months. Interpolated across the stage so
            // the target moves with the baby instead of jumping on a birthday.
            let t = ((months - 6) / 3).clamped(to: 0...1)
            let low = 30 + (60 - 30) * t
            let high = 45 + (125 - 45) * t
            return FeedingTargets(
                milkFeedsPerDay: 4...5,
                dailyMilkMl: milkRange,
                mealsPerDay: 2...3,
                snacksPerDay: 0...1,
                perMealGrams: low...high,
                energyFromSolidsKcal: 200,
                sourceIds: ["who.iycf2009", "who.iycf.fact", "who.cf2023", "aap.infantfeeding"]
            )

        case .buildingMeals:
            return FeedingTargets(
                milkFeedsPerDay: 3...4,
                dailyMilkMl: milkRange,
                mealsPerDay: 3...4,
                snacksPerDay: 1...2,
                perMealGrams: 100...125,
                energyFromSolidsKcal: 300,
                sourceIds: ["who.iycf2009", "who.iycf.fact", "who.cf2023"]
            )

        case .familyTable, .toddler:
            return FeedingTargets(
                milkFeedsPerDay: 2...3,
                dailyMilkMl: milkRange,
                mealsPerDay: 3...4,
                snacksPerDay: 1...2,
                perMealGrams: 150...200,
                energyFromSolidsKcal: 550,
                sourceIds: ["who.iycf2009", "who.iycf.fact", "who.cf2023", "espghan.cf2017"]
            )
        }
    }

    // MARK: - Stage content

    static func profile(for stage: AgeStage) -> StageProfile {
        switch stage {
        case .milkOnly:
            return StageProfile(stage: stage, headline: T(
                "Milk is the whole diet. Nothing else is needed yet — not water, not juice, not cereal in a bottle.",
                "Молоко — весь рацион. Больше пока ничего не нужно: ни воды, ни сока, ни каши в бутылочке."
            ), cards: [
                GuidanceCard(id: "milk.responsive", title: T("Feed on cues, not on a clock", "Кормите по сигналам, а не по часам"),
                    body: T("Rooting, hands to mouth and stirring come long before crying. Volume guides are per day, not per feed — babies even out across 24 hours.",
                            "Поисковый рефлекс, руки ко рту и возня появляются задолго до плача. Ориентиры по объёму — на сутки, а не на кормление: ребёнок сам выравнивает за 24 часа."),
                    sourceIds: ["nhs.weaning", "who.cf2023"]),
                GuidanceCard(id: "milk.vitd", title: T("Vitamin D from the first days", "Витамин D с первых дней"),
                    body: T("400 IU a day for breastfed and partially breastfed babies. Formula-fed babies taking about a litre a day usually get enough from the formula.",
                            "400 МЕ в день детям на грудном и смешанном вскармливании. Дети на смеси, выпивающие около литра в сутки, обычно получают достаточно из смеси."),
                    sourceIds: ["aap.vitdIron"]),
                GuidanceCard(id: "milk.nowater", title: T("No water yet", "Вода пока не нужна"),
                    body: T("Before 6 months, extra water displaces milk and can upset sodium balance. Breast milk and formula are mostly water already.",
                            "До 6 месяцев дополнительная вода вытесняет молоко и может нарушить баланс натрия. Грудное молоко и смесь и так почти целиком состоят из воды."),
                    sourceIds: ["who.cf2023", "nhs.weaning"]),
            ])

        case .gettingReady:
            return StageProfile(stage: stage, headline: T(
                "Watch for readiness rather than a date. Most babies are ready at around 6 months; some sit up ready at 5.",
                "Смотрите на признаки готовности, а не на дату. Большинство детей готовы примерно в 6 месяцев, некоторые — уже в 5."
            ), cards: [
                GuidanceCard(id: "ready.signs", title: T("The three signs", "Три признака"),
                    body: T("Holds their head steady and sits with support; brings things to their mouth and can coordinate eyes, hands and mouth; no longer pushes food back out with the tongue.",
                            "Уверенно держит голову и сидит с поддержкой; тянет предметы в рот и координирует глаза, руки и рот; больше не выталкивает еду языком."),
                    sourceIds: ["aap.solidfoods", "nhs.weaning"]),
                GuidanceCard(id: "ready.window", title: T("Not before 4 months, not after 6", "Не раньше 4 месяцев, не позже 6"),
                    body: T("ESPGHAN puts the window at 4–6 months; the WHO advises around 6. Starting before 4 months is the part everyone agrees to avoid.",
                            "ESPGHAN определяет окно как 4–6 месяцев, ВОЗ рекомендует около 6. Раньше 4 месяцев начинать не стоит — здесь согласны все."),
                    sourceIds: ["espghan.cf2017", "efsa.cf2019", "who.cf2023"]),
                GuidanceCard(id: "ready.iron", title: T("Iron becomes the priority", "Железо выходит на первый план"),
                    body: T("Iron stored before birth runs low around 6 months. From 4 months, breastfed babies are advised 1 mg/kg/day of iron until iron-rich solids are established.",
                            "Запасы железа, накопленные до рождения, истощаются примерно к 6 месяцам. С 4 месяцев детям на грудном вскармливании рекомендуют 1 мг/кг/сут железа, пока не установится прикорм, богатый железом."),
                    sourceIds: ["aap.vitdIron", "espghan.cf2017"]),
            ])

        case .firstTastes:
            return StageProfile(stage: stage, headline: T(
                "Milk is still the main nutrition. Solids are for learning — iron, texture and as many flavours as you can manage.",
                "Молоко по-прежнему основа питания. Прикорм — это обучение: железо, текстуры и как можно больше разных вкусов."
            ), cards: [
                GuidanceCard(id: "first.iron", title: T("Start with iron, not with fruit", "Начинайте с железа, а не с фруктов"),
                    body: T("Meat, liver, fish, egg, lentils and iron-fortified cereal come first. The classic 'apple then pear' order has no evidence behind it and delays the nutrient that actually matters.",
                            "Мясо, печень, рыба, яйцо, чечевица и обогащённая железом каша — в первую очередь. Классический порядок «яблоко, потом груша» ничем не подкреплён и откладывает то, что действительно важно."),
                    sourceIds: ["who.cf2023", "espghan.cf2017", "aap.vitdIron"]),
                GuidanceCard(id: "first.allergens", title: T("Introduce allergens now, and keep them in", "Аллергены вводите сейчас — и оставляйте в рационе"),
                    body: T("Egg, peanut, dairy, wheat, fish, sesame, soy, tree nuts and shellfish. One new allergen at a time, at home, earlier in the day. Once it goes well, keep offering it about twice a week — regular exposure is what the trials tested.",
                            "Яйцо, арахис, молочное, пшеница, рыба, кунжут, соя, орехи и морепродукты. По одному новому аллергену за раз, дома, в первой половине дня. Если прошло хорошо — давайте примерно дважды в неделю: в исследованиях проверяли именно регулярность."),
                    sourceIds: ["niaid.peanut2017", "leap2015", "eat2016", "espghan.cf2017"]),
                GuidanceCard(id: "first.amount", title: T("Amounts are a floor, not a quota", "Количество — это ориентир, а не норма"),
                    body: T("Start at 2–3 tablespoons a meal and grow towards half a 250 ml cup by 9 months. You decide what and when; the baby decides how much.",
                            "Начните с 2–3 столовых ложек за приём и растите к половине чашки 250 мл к 9 месяцам. Вы решаете что и когда, ребёнок решает сколько."),
                    sourceIds: ["who.iycf2009", "who.iycf.fact"]),
                GuidanceCard(id: "first.gag", title: T("Gagging is not choking", "Рвотный рефлекс — это не удушье"),
                    body: T("Gagging is loud, red-faced and protective — it pushes food forward. Choking is silent. Always seated upright, always supervised, never in a moving car or pram.",
                            "Рвотный рефлекс шумный, лицо краснеет — он защитный и выталкивает еду вперёд. Удушье беззвучно. Всегда сидя, всегда под присмотром, никогда в едущей машине или коляске."),
                    sourceIds: ["aap.choking2010"]),
                GuidanceCard(id: "first.water", title: T("Water in an open cup", "Вода в открытой чашке"),
                    body: T("Small amounts of water with meals from 6 months, in an open or straw cup. No juice, no sweetened drinks.",
                            "Немного воды во время еды с 6 месяцев, в открытой чашке или через трубочку. Никакого сока и сладких напитков."),
                    sourceIds: ["who.cf2023", "aap.juice2017"]),
            ])

        case .buildingMeals:
            return StageProfile(stage: stage, headline: T(
                "Three real meals plus a snack. Texture is now the lesson: lumps, soft pieces and self-feeding.",
                "Три полноценных приёма пищи плюс перекус. Главный урок теперь — текстура: комочки, мягкие кусочки и самостоятельная еда."
            ), cards: [
                GuidanceCard(id: "build.texture", title: T("Move past purée", "Уходите от гладкого пюре"),
                    body: T("There is a window around 9–10 months for accepting lumps. Children kept on smooth purée past it are markedly more likely to become selective eaters.",
                            "Примерно в 9–10 месяцев есть окно для принятия комочков. Дети, которых дольше держат на гладком пюре, заметно чаще становятся избирательными в еде."),
                    sourceIds: ["espghan.cf2017"]),
                GuidanceCard(id: "build.selffeed", title: T("Let them make a mess", "Разрешите устроить беспорядок"),
                    body: T("The pincer grasp arrives around now. Finger foods, a loaded spoon they hold themselves, an open cup — the mess is the mechanism.",
                            "Примерно сейчас появляется пинцетный захват. Еда руками, ложка, которую держит сам, открытая чашка — беспорядок и есть механизм обучения."),
                    sourceIds: ["who.cf2023", "aap.infantfeeding"]),
                GuidanceCard(id: "build.milkdown", title: T("Milk starts making room", "Молоко начинает уступать место"),
                    body: T("Offer solids first, milk after, so that food is not competing with a full stomach. Solids should now cover about 300 kcal a day.",
                            "Сначала предлагайте еду, потом молоко, чтобы прикорм не конкурировал с полным животом. Прикорм теперь должен покрывать примерно 300 ккал в сутки."),
                    sourceIds: ["who.iycf2009", "who.cf2023"]),
            ])

        case .familyTable, .toddler:
            return StageProfile(stage: stage, headline: T(
                "The same meal as everyone else — cooked without salt, chopped safely, served at the same table.",
                "То же блюдо, что и у всех, — приготовленное без соли, безопасно нарезанное и поданное за общим столом."
            ), cards: [
                GuidanceCard(id: "family.milk", title: T("Cow's milk can be the drink now", "Теперь коровье молоко можно как напиток"),
                    body: T("From 12 months, full-fat cow's milk in a cup. About 350–500 ml a day — more than that fills them up and crowds out iron.",
                            "С 12 месяцев — цельное коровье молоко в чашке. Примерно 350–500 мл в день: больше — и оно заполняет ребёнка, вытесняя железо."),
                    sourceIds: ["espghan.cf2017", "aap.infantfeeding"]),
                GuidanceCard(id: "family.sugar", title: T("Still no added sugar or salt", "По-прежнему без добавленного сахара и соли"),
                    body: T("No added sugar at all before 2 years. Season the family pot after the child's portion comes out.",
                            "Никакого добавленного сахара до 2 лет. Солите общее блюдо после того, как отложили порцию ребёнку."),
                    sourceIds: ["aha.sugar2017", "who.cf2023"]),
                GuidanceCard(id: "family.appetite", title: T("Appetite drops — that is expected", "Аппетит падает — так и должно быть"),
                    body: T("Growth slows sharply after the first year, and so does appetite. Neophobia peaks between 18 and 30 months. Keep offering without pressure; it can take 10–15 exposures.",
                            "После первого года рост резко замедляется, вместе с ним и аппетит. Пик пищевой неофобии — между 18 и 30 месяцами. Продолжайте предлагать без давления: иногда нужно 10–15 попыток."),
                    sourceIds: ["who.cf2023", "espghan.cf2017"]),
                GuidanceCard(id: "family.choking", title: T("Choking shapes still apply", "Опасные формы всё ещё актуальны"),
                    body: T("Grapes, cherry tomatoes and sausages stay quartered lengthwise. Whole nuts, popcorn and hard sweets wait until about 4 years.",
                            "Виноград, черри и сосиски по-прежнему режем вдоль на четвертинки. Целые орехи, попкорн и леденцы — не раньше примерно 4 лет."),
                    sourceIds: ["aap.choking2010"]),
            ])
        }
    }

    // MARK: - Allergens

    enum AllergenStatus: Hashable {
        case notStarted
        /// Tried, but not often enough or recently enough to count as maintained.
        case introduced(exposures: Int)
        /// Regular repeat exposure — what the prevention trials actually tested.
        case maintained(exposures: Int)
        case reacted
    }

    static func allergenStatus(
        _ allergen: Allergen, intros: [FoodIntro], on date: Date = Date()
    ) -> AllergenStatus {
        let foodIds = Set(FoodLibrary.all.filter { $0.allergen == allergen && !$0.isAvoid }.map(\.id))
        let relevant = intros.filter { foodIds.contains($0.foodId) }
        guard !relevant.isEmpty else { return .notStarted }

        if relevant.contains(where: { $0.worstReaction != .noReaction }) { return .reacted }

        let exposures = relevant.reduce(0) { $0 + $1.exposures }
        let lastOffered = relevant.map(\.lastOffered).max() ?? .distantPast
        let daysSince = Calendar.current.dateComponents([.day], from: lastOffered, to: date).day ?? 999

        if exposures >= 6 && daysSince <= 14 { return .maintained(exposures: exposures) }
        return .introduced(exposures: exposures)
    }

    // MARK: - Upcoming milestones

    struct Milestone: Identifiable, Hashable {
        let id: String
        let atMonths: Double
        let title: LocalizedText
        let detail: LocalizedText
        let sourceIds: [String]
    }

    static let milestones: [Milestone] = [
        Milestone(id: "vitD", atMonths: 0,
            title: T("Vitamin D, 400 IU daily", "Витамин D, 400 МЕ в день"),
            detail: T("From the first days for breastfed and partially breastfed babies, through the first year.",
                      "С первых дней детям на грудном и смешанном вскармливании, весь первый год."),
            sourceIds: ["aap.vitdIron"]),
        Milestone(id: "iron", atMonths: 4,
            title: T("Iron supplement for breastfed babies", "Препарат железа для детей на ГВ"),
            detail: T("1 mg/kg/day from 4 months until iron-rich solids are established. Ask your paediatrician.",
                      "1 мг/кг/сут с 4 месяцев, пока не установится прикорм с железом. Спросите педиатра."),
            sourceIds: ["aap.vitdIron"]),
        Milestone(id: "allergenWindow", atMonths: 4,
            title: T("Allergen window opens", "Открывается окно для аллергенов"),
            detail: T("Allergenic foods may be introduced from 4 months, in any order, once solids have started.",
                      "Аллергенные продукты можно вводить с 4 месяцев в любом порядке, как только начат прикорм."),
            sourceIds: ["espghan.cf2017", "niaid.peanut2017"]),
        Milestone(id: "solids", atMonths: 6,
            title: T("Complementary feeding starts", "Начало прикорма"),
            detail: T("Around 6 months, and not later — milk alone stops covering iron and zinc needs.",
                      "Примерно в 6 месяцев и не позже — одно молоко перестаёт покрывать потребность в железе и цинке."),
            sourceIds: ["who.cf2023", "espghan.cf2017"]),
        Milestone(id: "water", atMonths: 6,
            title: T("Water in an open cup", "Вода в открытой чашке"),
            detail: T("Small amounts with meals. Open or straw cup rather than a spouted bottle.",
                      "Понемногу во время еды. Открытая чашка или трубочка, а не поильник с носиком."),
            sourceIds: ["who.cf2023"]),
        Milestone(id: "lumps", atMonths: 9,
            title: T("Move to lumps and finger food", "Переход на комочки и еду руками"),
            detail: T("Delaying textures past about 10 months is associated with fussier eating later.",
                      "Если тянуть с текстурами дольше примерно 10 месяцев, позже чаще встречается избирательность в еде."),
            sourceIds: ["espghan.cf2017"]),
        Milestone(id: "cowMilk", atMonths: 12,
            title: T("Cow's milk as a drink", "Коровье молоко как напиток"),
            detail: T("Full-fat, in a cup, about 350–500 ml a day. Honey and diluted juice also become allowed at 12 months.",
                      "Цельное, в чашке, примерно 350–500 мл в день. Мёд и разбавленный сок также становятся допустимы с 12 месяцев."),
            sourceIds: ["espghan.cf2017", "cdc.botulism", "aap.juice2017"]),
        Milestone(id: "sugar", atMonths: 24,
            title: T("Added sugar remains off until 2", "Добавленный сахар — только после 2 лет"),
            detail: T("The recommendation is zero added sugar under 2 years, not 'a little'.",
                      "Рекомендация — ноль добавленного сахара до 2 лет, а не «немножко»."),
            sourceIds: ["aha.sugar2017"]),
        Milestone(id: "chokingShapes", atMonths: 48,
            title: T("Whole nuts, popcorn, hard sweets", "Целые орехи, попкорн, леденцы"),
            detail: T("These wait until about 4 years, when chewing and airway size have caught up.",
                      "Ждут примерно до 4 лет, когда дозреют жевание и размер дыхательных путей."),
            sourceIds: ["aap.choking2010"]),
    ]

    static func upcomingMilestones(months: Double, limit: Int = 4) -> [Milestone] {
        milestones.filter { $0.atMonths > months }.sorted { $0.atMonths < $1.atMonths }.prefix(limit).map { $0 }
    }

    static func currentMilestones(months: Double) -> [Milestone] {
        milestones.filter { $0.atMonths <= months }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
