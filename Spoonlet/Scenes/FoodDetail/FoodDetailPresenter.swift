import Foundation

protocol FoodDetailPresentationLogic {
    func presentFood(response: FoodDetail.Load.Response)
    func presentEmpty()
}

protocol FoodDetailDisplayLogic: AnyObject {
    func displayFood(viewModel: FoodDetail.Load.ViewModel)
}

final class FoodDetailPresenter: FoodDetailPresentationLogic {
    weak var view: FoodDetailDisplayLogic?

    func presentEmpty() {
        view?.displayFood(viewModel: .empty)
    }

    func presentFood(response: FoodDetail.Load.Response) {
        let food = response.food
        let isEarlyStage = response.months < 9

        view?.displayFood(viewModel: .init(
            emoji: food.emoji,
            name: food.name.text,
            groupTitle: food.group.title.text,
            statusText: statusText(response),
            statusDetail: statusDetail(response),
            statusKind: statusKind(response.availability),
            servingTitle: isEarlyStage
                ? String(localized: "How to serve at 6–8 months")
                : String(localized: "How to serve from 9 months"),
            servingText: isEarlyStage ? food.serveEarly.text : food.serveLater.text,
            otherServingTitle: isEarlyStage
                ? String(localized: "Later, from 9 months")
                : String(localized: "Earlier, at 6–8 months"),
            otherServingText: isEarlyStage ? food.serveLater.text : food.serveEarly.text,
            allergenText: food.allergen.map {
                String(localized: "Contains \($0.title.text) — one of the top-9 allergens. Offer it at home, earlier in the day, and keep it in the diet once it goes well.")
            },
            chokingText: chokingText(food),
            nutrientTitles: food.nutrients.map { $0.title.text },
            cautionText: food.caution?.text,
            historyText: historyText(response),
            overrideText: overrideText(response),
            sources: Evidence.sources(food.sourceIds).map {
                .init(id: $0.id, citation: $0.citation, title: $0.title,
                      kindLabel: $0.kind.label.text, takeaway: $0.takeaway.text,
                      urlString: $0.urlString)
            }
        ))
    }

    // MARK: - Pieces

    private func statusText(_ response: FoodDetail.Load.Response) -> String {
        switch response.availability {
        case .ready:
            return response.food.isAvoid
                ? String(localized: "Allowed from now")
                : String(localized: "Suitable now")
        case .soon:
            let month = Int((response.overrideMonth ?? Double(response.food.earliestMonth)).rounded())
            return String(localized: "Usually from \(month) months")
        case .notYet:
            return String(localized: "Not before \(response.food.hardLimitMonth ?? 12) months")
        }
    }

    private func statusDetail(_ response: FoodDetail.Load.Response) -> String {
        let ageText = String(format: "%.0f", response.months.rounded(.down))
        switch response.availability {
        case .ready:
            return String(localized: "Your baby is \(ageText) months old.")
        case .soon:
            return String(localized: "Your baby is \(ageText) months old. Nothing here says it is unsafe today — this is the age most guidance suggests.")
        case .notYet:
            return String(localized: "This is a hard limit with a safety reason behind it, not a preference. Read the sources below.")
        }
    }

    private func statusKind(_ availability: FoodAvailability) -> FoodDetail.Load.ViewModel.StatusKind {
        switch availability {
        case .ready: return .ready
        case .soon: return .soon
        case .notYet: return .blocked
        }
    }

    private func chokingText(_ food: Food) -> String? {
        switch food.choking {
        case .low: return nil
        case .moderate:
            return String(localized: "Cut with care — this food can form a choking shape if served whole or in coins.")
        case .high:
            return String(localized: "High choking risk. Follow the serving instructions exactly, keep your baby seated and upright, and stay within arm's reach.")
        }
    }

    private func historyText(_ response: FoodDetail.Load.Response) -> String? {
        guard let intro = response.intro else { return nil }
        let first = Fmt.fullDate(intro.firstOffered)
        let last = Fmt.relative(intro.lastOffered)
        if intro.exposures == 1 {
            return String(localized: "Tried once, on \(first).")
        }
        return String(format: String(localized: "%1$lld times since %2$@. Last offered %3$@."),
                      intro.exposures, first, last)
    }

    private func overrideText(_ response: FoodDetail.Load.Response) -> String? {
        guard let month = response.overrideMonth else { return nil }
        let attribution = response.overrideAttribution?.trimmingCharacters(in: .whitespaces) ?? ""
        let monthText = String(format: "%.0f", month)
        return attribution.isEmpty
            ? String(localized: "Your plan: from \(monthText) months.")
            : String(format: String(localized: "Your plan: from %1$@ months — %2$@."),
                     monthText, attribution)
    }
}
