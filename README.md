# GDATA Cockpit: data field master per Garmin Edge

Un unico data field Connect IQ che trasforma una pagina dell'Edge in un cockpit
completo. Cambia layout da solo:

- **Workout**: quando sull'Edge gira un allenamento strutturato, mostra lo step
  corrente, il tempo o la distanza che mancano, il target, lo step successivo e
  una barra che indica se sei dentro il target.
- **Gara**: senza workout mostra W' residuo, pendenza, VAM, NP, distanza alla
  meta e i promemoria per mangiare e bere, pensati per le Granfondo.

## Layout (pagina a 1 campo, schermo intero)

```
┌──────────────────────────────────────┐
│ 9:42          1:23:45           87%  │  ora · timer · batteria
├──────────────────────────────────────┤
│▌#3 LAVORO Soglia     POI 3:00 150-170W│  solo in modalità workout:
│▌  3:45                  240-260   W   │  tempo/dist. residui · target
├──────────────────────────────────────┤
│ PWR 3s Z4                 3.6 W/kg   │  potenza, sfondo = colore zona
│               252                    │  (in workout: blu sotto / verde
│                                      │   nel target / rosso sopra)
├──────────────────────────────────────┤
│░░░░░░░░░░████████░░░░|░░░░░░░░░░░░░░░│  barra target (workout) o W'bal
├──────────────────┬───────────────────┤
│▌FC Z3       bpm  │ CAD          rpm  │
│      148         │      92           │  griglia 2 colonne × 2-4 righe
├──────────────────┼───────────────────┤  (righe in base all'altezza
│ VEL        km/h  │▌PEND           %  │   dello schermo), riquadri
│     31.4         │      6.2          │   configurabili
├──────────────────┼───────────────────┤
│ ...              │ ...               │
├────────────┬─────┴──────┬────────────┤
│ CIBO 12:30 │ BERE 4:10  │ CHO 145g   │  promemoria rifornimento
└────────────┴────────────┴────────────┘
```

Il campo si adatta anche a layout con più campi:

- **Metà schermo**: banner workout (se attivo), potenza, barra e 2 riquadri.
- **Campo piccolo**: potenza a colori e barra. In workout aggiunge tempo
  residuo e target.

Lo sfondo chiaro o scuro segue l'impostazione dell'Edge.

## Metriche calcolate

| Metrica | Come |
|---|---|
| Potenza smussata | Media mobile su 1/3/5/10 s (impostabile). Le zone sono quelle di Coggan su % FTP: Z1 grigio, Z2 blu, Z3 verde, Z4 giallo, Z5 arancio, Z6 rosso, Z7 viola. |
| NP / IF / TSS | NP standard: media alla quarta potenza della media mobile a 30 s. Conta solo il tempo con timer attivo, quindi l'auto-pausa non abbassa i valori. |
| W' balance | Modello differenziale di Froncioni, Skiba e Clarke, con CP e W' impostabili. Avviso a soglia configurabile, che si riarma quando W' risale del 20%. |
| Pendenza | Δquota/Δdistanza su almeno 25 m, smussata. |
| VAM | Metri di salita nell'ultimo minuto, riportati a m/h. |
| CHO consumati | Stima: kJ meccanici ≈ kcal metaboliche. La quota di carboidrati cresce con l'intensità (circa 45% a 50% FTP, 90% a FTP). |
| FC | Zone e FC max lette dal profilo utente Garmin (bici). |
| Media step / giro | Si azzerano a ogni step del workout o a ogni giro. |

## Workout strutturati

- Lo step corrente viene letto con `Activity.getCurrentWorkoutStep()`.
- Le ripetute (`WorkoutIntervalStep`) sono gestite: in base all'intensità
  dello step viene scelta la parte di lavoro o quella di recupero.
- Per i target di potenza, FC, cadenza e velocità vengono mostrati range,
  unità e barra di aderenza. In workout, il colore dello sfondo della potenza
  segue l'aderenza al target.
- Con step a tempo o a distanza mostra quanto manca, e negli ultimi 10 s il
  conto alla rovescia diventa arancione. Con step aperti (fino al tasto lap)
  mostra il tempo trascorso, `+m:ss`.
- Anteprima dello step successivo (`getNextWorkoutStep`, API 3.3+).

Ci sono due problemi noti del firmware Garmin, gestiti nel codice:

- Alcune versioni restituiscono i target di potenza con l'offset FIT di +1000 W
  (1250 = 250 W). I valori sopra 1000 vengono corretti.
- I target in **% FTP** o **% FC max** arrivano come 0. Lo step appare come
  "LIBERO", senza barra target. Conviene quindi definire i workout con target
  in **watt** o **bpm** assoluti.

## Rifornimento (Granfondo)

- I promemoria **CIBO** e **BERE** hanno intervalli separati in minuti di
  timer, e il conto alla rovescia è sempre visibile nel footer.
- Alla scadenza compare un avviso a tutto schermo (`DataField.showAlert`) con il
  numero di rifornimenti fatti e i grammi di carboidrati consumati.
- Nell'ultimo minuto la cella del footer si colora.

## Registrazione FIT

Se l'opzione è attiva, nel file FIT vengono scritti:

- W' balance secondo per secondo, visibile come grafico in Garmin Connect;
- NP, TSS, CHO consumati e W' minimo, nel riepilogo dell'attività.

## Impostazioni

Si modificano da Garmin Connect Mobile o Connect IQ: *Dispositivo → Data field →
GDATA Cockpit → Impostazioni*.

| Impostazione | Default |
|---|---|
| Modalità cockpit: Auto (workout se caricato) / Sempre gara | Auto |
| FTP (W) | 250 |
| Potenza critica W (0 = usa FTP) | 0 |
| W' (J) | 20000 |
| Peso kg (0 = dal profilo utente) | 0 |
| Promemoria cibo / bere, minuti (0 = off) | 20 / 15 |
| Avviso W' basso % (0 = off) | 25 |
| Media potenza principale | 3 s |
| Registra nel file FIT | sì |
| Riquadri workout 1–8 | FC, CAD, W step, VEL, NP, TSS, IF, kJ |
| Riquadri gara 1–8 | FC, CAD, VEL, PEND, NP, VAM, DISL+, ALLA META |

Metriche disponibili per i riquadri: FC (zona), cadenza, velocità, velocità
media, potenza giro, potenza media, NP, IF, TSS, kJ, W/kg, pendenza, VAM,
dislivello, quota, distanza, distanza alla meta, tempo, tempo giro, W' residuo,
CHO, potenza step, potenza 30 s, % FC max, calorie.

Su schermi bassi (Edge 530/830/540/840) sono visibili i primi 6 riquadri, su
quelli alti (1040/1050/Explore 2) tutti e 8.

## Build e installazione

Servono il [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
(SDK Manager, SDK 7.x o successivo) e i device Edge scaricati.

```sh
# chiave sviluppatore (una volta sola)
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

# build per un dispositivo
monkeyc -f monkey.jungle -d edge1040 -o bin/GDataCockpit.prg -y developer_key.der

# simulatore
connectiq && monkeydo bin/GDataCockpit.prg edge1040
```

Per installarlo, copia il `.prg` in `GARMIN/APPS/` sull'Edge collegato via USB.
Poi aggiungi una pagina dati con layout **1 campo** e scegli *GDATA Cockpit*
tra i campi Connect IQ.

Nel simulatore: *Simulation → Data Fields → Timer start*, poi *Simulation →
FIT Data → Simulate Data* oppure *Playback File* con un FIT reale. Per provare
la modalità workout carica un workout con *Simulation → Workout*.

Dispositivi nel manifest: Edge 530, 540, 830, 840, 1030, 1030 Plus, 1040, 1050,
Explore 2. Se il tuo SDK lo supporta puoi aggiungere `edge550` / `edge850`.

## Struttura

```
source/
  GDataApp.mc      AppBase, ricarica impostazioni
  CockpitView.mc   DataField: compute(), layout adattivo, riquadri, avvisi
  Metrics.mc       id metriche + Engine (NP, TSS, W'bal, pendenza, VAM, CHO, fuel)
  Workout.mc       WorkoutTracker: step, target, residuo, step successivo
  Zones.mc         zone potenza/FC e colori
  Draw.mc          adattamento font, formattazione, unità
  AlertView.mc     pop-up DataFieldAlert
  FitRecorder.mc   campi FIT personalizzati
  Labels.mc        (generato) etichette dei riquadri
resources/         stringhe EN, impostazioni, icona, campi FIT
resources-ita/     stringhe IT
tools/gen_resources.py  genera stringhe, impostazioni, Labels.mc e icona
```

Per aggiungere una metrica:

1. Aggiungi la costante in `Metrics.mc` e la riga in `METRICS` dentro
   `tools/gen_resources.py`.
2. Lancia `python3 tools/gen_resources.py`.
3. Aggiungi il `case` in `CockpitView.metric()`.
