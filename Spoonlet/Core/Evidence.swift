import Foundation

/// The kind of thing a source is. Shown as a badge so a parent can tell a randomised
/// trial from an organisation's practice guideline without reading the citation.
enum EvidenceKind: String, Hashable, CaseIterable {
    case guideline
    case standard
    case trial
    case statement
    case publicHealth

    var label: LocalizedText {
        switch self {
        case .guideline: return T("Guideline", "Клинический гайд")
        case .standard: return T("Standard", "Стандарт")
        case .trial: return T("Randomised trial", "Рандомизированное исследование")
        case .statement: return T("Position paper", "Позиционный документ")
        case .publicHealth: return T("Public health advice", "Рекомендация ведомства")
        }
    }
}

struct EvidenceSource: Identifiable, Hashable {
    let id: String
    let organisation: String
    /// Publication titles stay in their original language — that is how they are cited
    /// and how a parent or doctor will find them again.
    let title: String
    let year: Int
    let urlString: String
    let kind: EvidenceKind
    /// One line on what this source actually establishes, in the reader's language.
    let takeaway: LocalizedText

    var url: URL? { URL(string: urlString) }

    /// Short form for the inline citation chips. The full `organisation` is spelled out in
    /// the sources list and on the detail screens; a chip has room for "WHO, 2023" and not
    /// for "World Health Organization, 2023". Derived from the id prefix so that adding a
    /// source from a body already in the table needs no extra field — an unknown prefix
    /// falls back to the full name rather than inventing an abbreviation.
    var abbreviation: String {
        switch id {
        case "leap2015": return "LEAP trial"
        case "eat2016": return "EAT trial"
        case let id where id.hasPrefix("who."): return "WHO"
        case let id where id.hasPrefix("aap."): return "AAP"
        case let id where id.hasPrefix("espghan."): return "ESPGHAN"
        case let id where id.hasPrefix("efsa."): return "EFSA"
        case let id where id.hasPrefix("niaid."): return "NIAID"
        case let id where id.hasPrefix("nhs."): return "NHS"
        case let id where id.hasPrefix("fda."): return "FDA"
        case let id where id.hasPrefix("cdc."): return "CDC"
        case let id where id.hasPrefix("aha."): return "AHA"
        default: return organisation
        }
    }

    var citation: String { "\(abbreviation), \(year)" }
}

/// Every recommendation surface in Spoonlet carries source ids that resolve here.
/// Nothing is asserted in the UI without a row in this table.
enum Evidence {
    static let all: [EvidenceSource] = [
        EvidenceSource(
            id: "who.cf2023",
            organisation: "World Health Organization",
            title: "Guideline for complementary feeding of infants and young children 6–23 months of age",
            year: 2023,
            urlString: "https://www.who.int/publications/i/item/9789240081864",
            kind: .guideline,
            takeaway: T(
                "Complementary foods start at 6 months; breastfeeding continues to 2 years or beyond. Animal-source foods, fruit, vegetables, pulses and nuts should carry the energy, not starchy staples.",
                "Прикорм начинают в 6 месяцев; грудное вскармливание продолжают до 2 лет и дольше. Основу калорий должны давать продукты животного происхождения, овощи, фрукты, бобовые и орехи, а не крахмалистые каши."
            )
        ),
        EvidenceSource(
            id: "who.iycf2009",
            organisation: "World Health Organization",
            title: "Infant and Young Child Feeding: Model Chapter for Textbooks for Medical Students and Allied Health Professionals",
            year: 2009,
            urlString: "https://www.who.int/publications/i/item/9789241597494",
            kind: .guideline,
            takeaway: T(
                "The source of the classic portion ladder: 2–3 tablespoons per meal at 6 months, growing to half a 250 ml cup by 9 months and about ¾ of a cup at 12–23 months.",
                "Источник классической «лестницы порций»: 2–3 столовые ложки на приём в 6 месяцев, к 9 месяцам — половина чашки 250 мл, в 12–23 месяца — около ¾ чашки."
            )
        ),
        EvidenceSource(
            id: "who.iycf.fact",
            organisation: "World Health Organization",
            title: "Infant and young child feeding (fact sheet)",
            year: 2023,
            urlString: "https://www.who.int/news-room/fact-sheets/detail/infant-and-young-child-feeding",
            kind: .publicHealth,
            takeaway: T(
                "Meal frequency: 2–3 meals a day at 6–8 months, 3–4 meals a day at 9–23 months, plus 1–2 nutritious snacks.",
                "Частота приёмов: 2–3 раза в день в 6–8 месяцев, 3–4 раза в день в 9–23 месяца плюс 1–2 питательных перекуса."
            )
        ),
        EvidenceSource(
            id: "who.growth2006",
            organisation: "World Health Organization",
            title: "WHO Child Growth Standards",
            year: 2006,
            urlString: "https://www.who.int/tools/child-growth-standards",
            kind: .standard,
            takeaway: T(
                "The growth curves in this app. Built from healthy, breastfed children across six countries — they describe how children should grow, not merely how they do.",
                "Кривые роста, которые использует это приложение. Построены на здоровых детях на грудном вскармливании из шести стран — описывают, как ребёнок должен расти, а не как растёт в среднем."
            )
        ),
        EvidenceSource(
            id: "espghan.cf2017",
            organisation: "ESPGHAN Committee on Nutrition",
            title: "Complementary Feeding: A Position Paper by the ESPGHAN Committee on Nutrition",
            year: 2017,
            urlString: "https://doi.org/10.1097/MPG.0000000000001454",
            kind: .statement,
            takeaway: T(
                "Complementary foods should not start before 4 months and should not be delayed beyond 6 months. Allergenic foods may be introduced from 4 months in any order. Cow's milk should not be the main drink before 12 months.",
                "Прикорм не начинают раньше 4 месяцев и не откладывают позже 6. Аллергенные продукты можно вводить с 4 месяцев в любом порядке. Коровье молоко не должно быть основным напитком до 12 месяцев."
            )
        ),
        EvidenceSource(
            id: "efsa.cf2019",
            organisation: "European Food Safety Authority",
            title: "Appropriate age range for introduction of complementary feeding into an infant's diet",
            year: 2019,
            urlString: "https://doi.org/10.2903/j.efsa.2019.5780",
            kind: .statement,
            takeaway: T(
                "Found no evidence of harm from introducing complementary foods between 3–4 and 6 months in European infants, while noting that around 6 months suits most.",
                "Не нашли доказательств вреда от введения прикорма между 3–4 и 6 месяцами у европейских детей, отмечая, что большинству подходит возраст около 6 месяцев."
            )
        ),
        EvidenceSource(
            id: "niaid.peanut2017",
            organisation: "NIAID-sponsored expert panel",
            title: "Addendum guidelines for the prevention of peanut allergy in the United States",
            year: 2017,
            urlString: "https://doi.org/10.1016/j.jaci.2016.10.010",
            kind: .guideline,
            takeaway: T(
                "Three risk tiers. Severe eczema and/or egg allergy: see a doctor about testing and introduce peanut at 4–6 months. Mild-to-moderate eczema: around 6 months. No eczema or food allergy: whenever the family chooses, with other solids.",
                "Три группы риска. Тяжёлая экзема и/или аллергия на яйцо: обсудить с врачом тестирование и ввести арахис в 4–6 месяцев. Лёгкая или умеренная экзема: около 6 месяцев. Без экземы и пищевой аллергии: в любой момент вместе с другим прикормом."
            )
        ),
        EvidenceSource(
            id: "leap2015",
            organisation: "Du Toit et al., NEJM",
            title: "Randomized Trial of Peanut Consumption in Infants at Risk for Peanut Allergy (LEAP)",
            year: 2015,
            urlString: "https://doi.org/10.1056/NEJMoa1414850",
            kind: .trial,
            takeaway: T(
                "In high-risk infants, eating peanut regularly from 4–11 months cut peanut allergy at age 5 dramatically compared with avoiding it. This trial is why the avoidance advice was reversed.",
                "У детей группы высокого риска регулярное употребление арахиса с 4–11 месяцев резко снизило частоту аллергии на арахис к 5 годам по сравнению с избеганием. Именно это исследование развернуло прежние рекомендации."
            )
        ),
        EvidenceSource(
            id: "eat2016",
            organisation: "Perkin et al., NEJM",
            title: "Randomized Trial of Introduction of Allergenic Foods in Breast-Fed Infants (EAT)",
            year: 2016,
            urlString: "https://doi.org/10.1056/NEJMoa1514210",
            kind: .trial,
            takeaway: T(
                "Early introduction of six allergenic foods from 3 months was safe, but did not reduce allergy in the intention-to-treat analysis — families struggled to keep up the required amounts.",
                "Раннее введение шести аллергенных продуктов с 3 месяцев оказалось безопасным, но не снизило частоту аллергии в основном анализе — семьям было трудно выдерживать нужные объёмы."
            )
        ),
        EvidenceSource(
            id: "aap.infantfeeding",
            organisation: "American Academy of Pediatrics",
            title: "Infant Food and Feeding",
            year: 2024,
            urlString: "https://www.aap.org/en/patient-care/healthy-active-living-for-families/infant-food-and-feeding/",
            kind: .guideline,
            takeaway: T(
                "Around 6 months a baby typically has 4–5 milk feeds a day plus 1–2 solid meals of a few tablespoons; by 12 months roughly half of energy comes from solids.",
                "Примерно в 6 месяцев у ребёнка обычно 4–5 молочных кормлений в день плюс 1–2 приёма прикорма по несколько столовых ложек; к 12 месяцам около половины калорий даёт твёрдая пища."
            )
        ),
        EvidenceSource(
            id: "aap.solidfoods",
            organisation: "American Academy of Pediatrics (HealthyChildren)",
            title: "Starting Solid Foods",
            year: 2024,
            urlString: "https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/Starting-Solid-Foods.aspx",
            kind: .publicHealth,
            takeaway: T(
                "Readiness is developmental, not calendar-based: good head control, sitting with support, and reaching for food rather than pushing it out with the tongue.",
                "Готовность определяется развитием, а не календарём: уверенно держит голову, сидит с поддержкой, тянется к еде и больше не выталкивает её языком."
            )
        ),
        EvidenceSource(
            id: "aap.vitdIron",
            organisation: "American Academy of Pediatrics (HealthyChildren)",
            title: "Where We Stand: Vitamin D & Iron Supplements for Babies",
            year: 2022,
            urlString: "https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/Vitamin-Iron-Supplements.aspx",
            kind: .publicHealth,
            takeaway: T(
                "400 IU of vitamin D a day for breastfed and partially breastfed babies from the first days. From 4 months, 1 mg/kg/day of iron until iron-rich solids are established.",
                "400 МЕ витамина D в день для детей на грудном и смешанном вскармливании с первых дней. С 4 месяцев — 1 мг/кг/сут железа, пока не установится прикорм, богатый железом."
            )
        ),
        EvidenceSource(
            id: "aap.juice2017",
            organisation: "Heyman & Abrams, Pediatrics (AAP)",
            title: "Fruit Juice in Infants, Children, and Adolescents: Current Recommendations",
            year: 2017,
            urlString: "https://doi.org/10.1542/peds.2017-0967",
            kind: .statement,
            takeaway: T(
                "No fruit juice at all before 12 months — it offers no advantage over whole fruit and displaces milk and nutrients.",
                "Никакого фруктового сока до 12 месяцев — он не даёт преимуществ перед целым фруктом и вытесняет молоко и питательные вещества."
            )
        ),
        EvidenceSource(
            id: "aap.choking2010",
            organisation: "AAP Committee on Injury, Violence, and Poison Prevention",
            title: "Prevention of Choking Among Children",
            year: 2010,
            urlString: "https://doi.org/10.1542/peds.2009-2862",
            kind: .statement,
            takeaway: T(
                "The high-risk shapes are round, firm and compressible: whole grapes, hot dog rounds, whole nuts, hard sweets, popcorn, raw hard vegetables. Cut, don't skip.",
                "Опаснее всего круглое, плотное и сжимаемое: целый виноград, сосиска кружочками, целые орехи, леденцы, попкорн, сырые твёрдые овощи. Резать, а не исключать."
            )
        ),
        EvidenceSource(
            id: "aha.sugar2017",
            organisation: "Vos et al., Circulation (AHA)",
            title: "Added Sugars and Cardiovascular Disease Risk in Children: A Scientific Statement",
            year: 2017,
            urlString: "https://doi.org/10.1161/CIR.0000000000000439",
            kind: .statement,
            takeaway: T(
                "No added sugar at all under the age of 2.",
                "Никакого добавленного сахара до 2 лет."
            )
        ),
        EvidenceSource(
            id: "fda.fish",
            organisation: "US FDA & EPA",
            title: "Advice about Eating Fish",
            year: 2024,
            urlString: "https://www.fda.gov/food/consumers/advice-about-eating-fish",
            kind: .publicHealth,
            takeaway: T(
                "Serve low-mercury fish (salmon, sardine, cod, tilapia) 1–2 times a week from the start of solids; avoid shark, swordfish, king mackerel, bigeye tuna and tilefish.",
                "С самого начала прикорма давать рыбу с низким содержанием ртути (лосось, сардина, треска, тилапия) 1–2 раза в неделю; избегать акулы, меч-рыбы, королевской макрели, большеглазого тунца и малакантовых."
            )
        ),
        EvidenceSource(
            id: "nhs.weaning",
            organisation: "NHS Start for Life",
            title: "What to feed your baby / Bottle feeding advice",
            year: 2024,
            urlString: "https://www.nhs.uk/start-for-life/baby/weaning/",
            kind: .publicHealth,
            takeaway: T(
                "Formula-fed babies need roughly 150–200 ml per kilogram of body weight per day until around 6 months, fed responsively rather than to a fixed number.",
                "Детям на смеси нужно примерно 150–200 мл на килограмм веса в сутки примерно до 6 месяцев, при этом кормить по требованию, а не по фиксированной цифре."
            )
        ),
        EvidenceSource(
            id: "cdc.botulism",
            organisation: "US Centers for Disease Control and Prevention",
            title: "About Botulism",
            year: 2024,
            urlString: "https://www.cdc.gov/botulism/about/index.html",
            kind: .publicHealth,
            takeaway: T(
                "Never give honey — raw, cooked or baked — before 12 months. Spores that an adult gut handles easily can cause infant botulism.",
                "Никогда не давать мёд — ни сырой, ни варёный, ни в выпечке — до 12 месяцев. Споры, с которыми легко справляется кишечник взрослого, у младенца могут вызвать ботулизм."
            )
        ),
    ]

    private static let index: [String: EvidenceSource] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func source(_ id: String) -> EvidenceSource? { index[id] }

    static func sources(_ ids: [String]) -> [EvidenceSource] { ids.compactMap { index[$0] } }
}
