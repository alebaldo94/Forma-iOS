# Forma per iPhone + Apple Watch

App SwiftUI (iOS 17+, Apple Watch con watchOS 10+) che:
1. fa il login con le credenziali Forma (nome / cognome);
2. scarica da `https://forma.appartiene.org` gli allenamenti creati dall'allenatore;
3. li programma nell'app **Allenamento** dell'Apple Watch con **WorkoutKit** (passi, durate, e avviso di frequenza cardiaca per passo: il cliente vede la FC sul Watch e viene avvisato se esce dal range);
4. dopo la sessione legge da HealthKit la FC registrata dal Watch e la invia a Forma (grafico, tempo nel range per passo e limiti superati su `/sessioni`).

Nessuna app Watch separata: i workout programmati con WorkoutKit compaiono da soli nell'app Allenamento del Watch.

## Come si compila (serve un Mac)

1. Mac con Xcode 16+ e un account Apple Developer (99 EUR/anno: serve per HealthKit su dispositivo reale e per TestFlight).
2. `brew install xcodegen`
3. `cd ios && xcodegen` -> genera `Forma.xcodeproj`
4. Apri il progetto, in *Signing & Capabilities* scegli il tuo Team (il bundle id e' `org.appartiene.forma`, cambialo se occupato). Le capability HealthKit sono gia' nell'entitlements.
5. Collega un iPhone con Apple Watch associato, Run. Per i clienti: Product > Archive > TestFlight.

## Prova rapida
- Da Claude (MCP): `forma_crea_workout` per un atleta con la spunta "allenamenti" attiva nel profilo.
- Apri l'app, tira giu' per aggiornare: l'allenamento compare e, accettato il permesso, sul Watch in Allenamento.
- Dopo la sessione riapri l'app: il risultato parte da solo e appare su `/sessioni`.

## Note
- Il codice e' stato scritto contro la documentazione Apple di WorkoutKit/HealthKit ma non e' stato compilato (nessun Mac disponibile durante lo sviluppo): al primo build possono servire piccoli ritocchi.
- Il cliente deve concedere a Forma il permesso di programmare allenamenti (alla prima apertura) e la lettura di FC/allenamenti in Salute.
- Il Watch mostra la FC e avvisa fuori range da solo; le segnalazioni all'allenatore per i limiti sono per ora solo registrate (evento `fuori_limiti` in `/api/eventi`).
