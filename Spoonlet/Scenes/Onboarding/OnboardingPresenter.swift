import Foundation

enum OnboardingValidationError {
    case futureBirthDate
}

protocol OnboardingPresentationLogic {
    func presentSaved(response: Onboarding.Save.Response)
    func presentValidationError(message: OnboardingValidationError)
}

protocol OnboardingDisplayLogic: AnyObject {
    func display(viewModel: Onboarding.Save.ViewModel)
}

final class OnboardingPresenter: OnboardingPresentationLogic {
    weak var view: OnboardingDisplayLogic?

    func presentSaved(response: Onboarding.Save.Response) {
        view?.display(viewModel: .init(didSave: true, errorText: nil))
    }

    func presentValidationError(message: OnboardingValidationError) {
        let text: String
        switch message {
        case .futureBirthDate:
            text = String(localized: "That date is in the future.")
        }
        view?.display(viewModel: .init(didSave: false, errorText: text))
    }
}
