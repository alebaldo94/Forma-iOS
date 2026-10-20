import Foundation
import HealthKit

/// Legge da HealthKit l'allenamento svolto sull'Apple Watch e la sua serie di frequenza cardiaca.
final class HealthReader {
    private let store = HKHealthStore()
    private let hrType = HKQuantityType(.heartRate)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorize() async throws {
        try await store.requestAuthorization(toShare: [], read: [hrType, HKObjectType.workoutType()])
    }

    /// Allenamento registrato nel giorno `day` del tipo atteso (il piu' recente).
    func workout(on day: Date, activity: HKWorkoutActivityType) async throws -> HKWorkout? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
        let desc = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKObjectType.workoutType(), predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let found = try await desc.result(for: store).compactMap { $0 as? HKWorkout }
        return found.first { $0.workoutActivityType == activity } ?? found.first
    }

    /// Coppie [secondi dall'inizio, bpm].
    func heartRate(for workout: HKWorkout) async throws -> [[Double]] {
        let pred = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let desc = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await desc.result(for: store).map {
            [$0.startDate.timeIntervalSince(workout.startDate), $0.quantity.doubleValue(for: unit)]
        }
    }
}
