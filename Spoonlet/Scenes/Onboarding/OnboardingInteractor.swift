import Foundation

protocol OnboardingBusinessLogic {
    func save(request: Onboarding.Save.Request)
}

final class OnboardingInteractor: OnboardingBusinessLogic {
    private let presenter: OnboardingPresentationLogic
    private let worker: StorageWorker

    init(presenter: OnboardingPresentationLogic, worker: StorageWorker = .shared) {
        self.presenter = presenter
        self.worker = worker
    }

    func save(request: Onboarding.Save.Request) {
        let trimmed = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard request.birthDate <= Date() else {
            presenter.presentValidationError(message: .futureBirthDate)
            return
        }

        let child = Child(
            name: trimmed.isEmpty ? String(localized: "Baby") : trimmed,
            birthDate: request.birthDate,
            sex: request.sex,
            gestationWeeks: request.gestationWeeks
        )
        worker.save(child: child)

        var settings = worker.settings()
        settings.activeChildId = child.id
        settings.units = request.units
        // Accepting the disclaimer is the last step of onboarding, so reaching here means
        // the parent has read it — recorded with a timestamp for App Review.
        settings.disclaimerAcceptedAt = Date()
        worker.save(settings: settings)

        presenter.presentSaved(response: .init(
            child: child,
            stage: AgeStage.stage(forMonths: child.ageMonths())
        ))
    }
}
