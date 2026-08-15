import Foundation

enum Onboarding {
    enum Save {
        struct Request {
            let name: String
            let birthDate: Date
            let sex: ChildSex
            let gestationWeeks: Int
            let units: UnitSystem
        }

        struct Response {
            let child: Child
            let stage: AgeStage
        }

        struct ViewModel {
            let didSave: Bool
            let errorText: String?
        }
    }
}
