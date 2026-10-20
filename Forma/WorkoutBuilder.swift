import Foundation
import HealthKit
import WorkoutKit

/// Traduce un allenamento Forma in un WorkoutPlan di WorkoutKit (appare nell'app Allenamento dell'Apple Watch,
/// con avviso di frequenza cardiaca quando un passo ha un range "fc").
enum WorkoutBuilder {
    static func activity(_ sport: String) -> HKWorkoutActivityType {
        switch sport {
        case "bici": return .cycling
        case "camminata": return .walking
        default: return .running
        }
    }

    static func goal(_ p: Passo) -> WorkoutGoal {
        if let s = p.durata_sec { return .time(Double(s), .seconds) }
        if let m = p.distanza_m { return .distance(Double(m), .meters) }
        return .open
    }

    static func alert(_ p: Passo) -> (any WorkoutAlert)? {
        guard let fc = p.fc, fc.count == 2, fc[0] < fc[1] else { return nil }
        return HeartRateRangeAlert.heartRate(Double(fc[0])...Double(fc[1]))   // unita' predefinita: battiti/minuto
    }

    static func step(_ p: Passo) -> WorkoutStep {
        WorkoutStep(goal: goal(p), alert: alert(p), displayName: p.nome)
    }

    static func plan(_ w: FormaWorkout) -> WorkoutPlan {
        let blocks = w.blocchi.map { b in
            IntervalBlock(
                steps: b.passi.map { IntervalStep($0.scopo == "recovery" ? .recovery : .work, step: step($0)) },
                iterations: b.ripetizioni)
        }
        let custom = CustomWorkout(
            activity: activity(w.sport),
            location: w.luogo == "indoor" ? .indoor : .outdoor,
            displayName: w.nome,
            warmup: w.riscaldamento.map { step($0) },
            blocks: blocks,
            cooldown: w.defaticamento.map { step($0) })
        return WorkoutPlan(.custom(custom), id: UUID(uuidString: w.id) ?? UUID())
    }

    /// Orario di inizio programmato (il Watch mostra l'allenamento nel giorno indicato).
    static func dateComponents(_ w: FormaWorkout, hour: Int = 8) -> DateComponents? {
        guard let d = w.giorno else { return nil }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        c.hour = hour
        c.minute = 0
        return c
    }
}
