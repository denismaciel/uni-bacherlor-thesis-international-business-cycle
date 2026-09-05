#let ink = rgb("202b30")
#let accent = rgb("27665d")
#let muted = rgb("64716f")
#let light = rgb("edf3f1")

#let thesis(body) = {
  set document(title: "International Business Cycles: Theory and Evidence — Have the conclusions changed?", author: "Denis Augusto Pinto Maciel", date: datetime(year: 2026, month: 9, day: 6))
  set text(font: "Libertinus Serif", size: 11pt, fill: ink, lang: "en")
  set page(paper: "a4", margin: (left: 25mm, right: 23mm, top: 22mm, bottom: 23mm), numbering: "1", number-align: right,
    header: context {
      if counter(page).get().first() > 1 {
        set text(font: "DejaVu Sans", size: 7pt, fill: muted)
        [INTERNATIONAL BUSINESS CYCLES #h(1fr) DENIS MACIEL]
        v(3pt)
        line(length: 100%, stroke: 0.4pt + rgb("cbd6d2"))
      }
    },
    footer: context {
      set text(font: "DejaVu Sans", size: 8pt, fill: muted)
      align(right, counter(page).display())
    })
  set par(justify: true, leading: 0.65em, spacing: 0.8em)
  set heading(numbering: "1.1", supplement: [Section])
  show heading: set text(font: "DejaVu Sans", fill: ink, weight: "bold")
  show heading.where(level: 1): set text(size: 21pt, fill: accent)
  show heading.where(level: 1): set block(above: 16pt, below: 18pt)
  show heading.where(level: 2): set text(size: 12pt)
  show heading.where(level: 2): set block(above: 18pt, below: 8pt)
  show link: set text(fill: accent)
  show ref: set text(fill: accent)
  set cite(style: "chicago-author-date")
  set bibliography(style: "chicago-author-date")
  show bibliography: set text(size: 9.2pt)
  show bibliography: set par(leading: 0.45em)
  show footnote.entry: set text(size: 8.5pt)
  set figure(gap: 8pt)
  show figure.caption: set text(size: 9pt)
  show figure.caption: set par(justify: false, leading: 0.45em)
  set table(stroke: none, inset: (x: 4pt, y: 5pt), align: (x, y) => if x == 0 { left } else { center })
  body
}

#let clean-table(headers, rows, columns: auto, size: 8.5pt) = {
  set text(font: "DejaVu Sans", size: size)
  set par(justify: false, leading: 0.4em)
  table(columns: if columns == auto { (auto, ..range(headers.len() - 1).map(_ => 1fr)) } else { columns },
    table.hline(stroke: 0.8pt + accent),
    table.header(..headers.map(h => text(weight: "bold", h))),
    table.hline(stroke: 0.4pt + accent),
    ..rows.enumerate().map(((i, row)) => row.map(cell => table.cell(fill: if calc.even(i) { light } else { none }, cell))).flatten(),
    table.hline(stroke: 0.6pt + accent),
  )
}
#let note(body) = { v(5pt); text(size: 8pt, fill: muted, body) }
#let pub = json("data/publication-tables.json")
#let comparison(value) = {
  if type(value) != str { return value }
  let normalized = value.replace("(", " (").replace("[", " [").trim()
  let parts = normalized.split(regex(" +"))
  if parts.len() == 2 { [#parts.first()\ #text(size: 7pt, fill: muted, parts.last())] }
  else if value.starts-with("(") { [—\ #text(size: 7pt, fill: muted, value)] }
  else { value }
}
#let publication-table(id, caption) = {
  let rows = pub.at(id)
  let headers = ()
  let size = 8pt
  if id == "3" {
    headers = ([Country], [GDP], [Consumption], [Investment], [Government], [Net exports], [Employment])
    rows = rows.map(row => (row.first(), ..range(6).map(i => {
      let last = row.at(1 + i * 2).replace("-Q", ":")
      let first = row.at(2 + i * 2).replace("-Q", ":")
      if first == "" { [—] } else { [#first\ – #last] }
    })))
    size = 7.5pt
  } else if id == "4" { headers = ([Country], $y$, $n x$, $c$, $x$, $g$, $n$, $z$) }
  else if id == "5" { headers = ([Country], [Autocorr.], $c$, $x$, $g$, $n x$, $n$, $z$) }
  else if id == "6" { headers = ([Country], $y$, $c$, $x$, $g$, $n x$, $n$, $z$) }
  else { headers = ([Variable], [Mean], [US mean], [0%], [10%], [25%], [40%], [50%], [60%], [75%], [90%], [100%]); size = 7.8pt }
  figure(kind: table, supplement: [Table], caption: caption, {
    if id == "4" { note[$y$ and $n x$: standard deviations (%). Remaining columns: ratio to output volatility.]; v(6pt) }
    clean-table(headers, rows.map(row => row.map(comparison)), size: size)
    if id == "3" { note[Each cell gives first–last quarter. A dash denotes an unavailable series.] }
    else { note[Original 2015 publication values. Parentheses: BKK (1993). Square brackets: ACZ (2004). A dash denotes an unavailable estimate.] }
  })
}
#let model-table() = figure(kind: table, supplement: [Table], caption: [Standard Deviations, Within- and Cross-country Comovements from Models], {
  text(size: 9pt, weight: "bold")[(a) Volatility: standard deviations and ratios to output]
  v(6pt)
  clean-table(([Model], $sigma_y$, $sigma_(n x)$, $c$, $x$, $n$, $z$), (
    ([Closed economy], [1.80], [—], [0.35], [3.58], [0.58], [0.50]),
    ([Benchmark], [1.50], [3.77], [0.42], [10.99], [0.50], [0.67]),
    ([Transport cost], [1.35], [0.37], [0.47], [2.91], [0.47], [0.75]),
    ([Autarky], [1.26], [—], [0.54], [2.65], [0.91], [0.99]),
  ))
  v(10pt)
  text(size: 9pt, weight: "bold")[(b) Within-country correlations with output]
  v(6pt)
  clean-table(([Model], $c$, $x$, $n x$, $n$, $z$), (
    ([Closed economy], [.94], [.80], [—], [.93], [.90]),
    ([Benchmark], [.77], [.27], [.01], [.93], [.89]),
    ([Transport cost], [.81], [.92], [.23], [.92], [.98]),
    ([Autarky], [.90], [.96], [—], [.91], [.99]),
  ))
  v(10pt)
  text(size: 9pt, weight: "bold")[(c) Cross-country correlations]
  v(6pt)
  clean-table(([Model], $y$, $c$, $x$, $n$, $z$), (
    ([Benchmark], [−.21], [.88], [−.94], [−.78], [.25]),
    ([Transport cost], [−.05], [.89], [−.48], [−.70], [.25]),
    ([Autarky], [.08], [.56], [−.31], [−.51], [.25]),
  ))
})
#let variables-table() = figure(kind: table, supplement: [Table], caption: [Variable Specification of OECD], clean-table(
  ([Variable], [Name], [Code], [Measure]), (
  ($y$, [Gross domestic product — expenditure approach], [B1_GE], [VPVOBARSA]),
  ($c$, [Private final consumption expenditure], [P31S14_S15], [VPVOBARSA]),
  ($x$, [Gross fixed capital formation], [P51], [VPVOBARSA]),
  ($g$, [General government final consumption expenditure], [P3S13], [VPVOBARSA]),
  ($n$, [Employed population, aged 15 and over, all persons], [LFEMTTTT], [STSA]),
  ($n x$, [Exports of goods and services], [P6], [CPCARSA]),
  ([], [Imports of goods and services], [P7], [CPCARSA]),
  ([], [Gross domestic product — expenditure approach], [B1_GE], [CPCARSA]),
), columns: (0.6fr, 3fr, 1.25fr, 1.3fr), size: 7.8pt))
#let measure-table() = figure(kind: table, supplement: [Table], caption: [Cross-country Correlation of US Output in Four Different Measures, 1970:1–1990:2], clean-table(
  ([Measure], [AUS], [AUT], [CAN], [CHE], [DEU], [FRA], [GBR], [ITA], [JPN], [USA]), (
  ([BKK (1993)], [.51], [.38], [.76], [.42], [.69], [.41], [.55], [.41], [.60], [1.00]),
  ([ACZ (2004)], [.40], [.32], [.77], [.35], [.50], [.27], [.68], [.33], [.39], [1.00]),
  ([CARSA], [.00], [.08], [.29], [.11], [.29], [−.14], [−.01], [−.04], [.22], [1.00]),
  ([CPCARSA], [.27], [−.00], [.56], [.26], [.41], [.11], [.30], [.24], [.38], [1.00]),
  ([VOBARSA], [.35], [.29], [.71], [.41], [.66], [.39], [.62], [.37], [.60], [1.00]),
  ([VPVOBARSA], [.35], [.29], [.71], [.41], [.66], [.39], [.62], [.37], [.60], [1.00]),
), size: 7pt))
#let employment-table() = figure(kind: table, supplement: [Table], caption: [Length of Employed Population Series from Short-Term Labour Market Statistics], clean-table(
  ([Country], [First quarter], [Last quarter]), (
    ([AUS], [1967:1], [2015:2]), ([AUT], [1969:1], [2015:1]), ([CAN], [1955:1], [2015:2]),
    ([FRA], [2003:1], [2015:1]), ([DEU], [1962:1], [2015:1]), ([ITA], [1998:1], [2015:1]),
    ([JPN], [1955:1], [2015:2]), ([CHE], [1998:2], [2015:1]), ([GBR], [1999:2], [2015:1]),
    ([USA], [1955:1], [2015:2]), ([EA19], [2005:1], [2015:1]),
)))
#let chart(file, caption) = figure(image("assets/" + file, width: 100%, alt: "Thesis chart: " + file), caption: caption)
#let correlation-figure() = figure(grid(columns: (1fr, 1fr), gutter: 12pt,
  [#image("assets/gdpcor.svg", width: 100%, alt: "Sorted output correlations, with US pairs highlighted")\ #text(size: 9pt)[(a) Output correlations]],
  [#image("assets/concor.svg", width: 100%, alt: "Sorted consumption correlations, with US pairs highlighted")\ #text(size: 9pt)[(b) Consumption correlations]],
), caption: [Output and Consumption Correlations among all Countries])
#let employment-figure() = figure(grid(columns: 1, gutter: 9pt,
  ..(("fra", "France"), ("gbr", "United Kingdom"), ("ita", "Italy")).map(((code, name)) => [
    #text(size: 9pt, weight: "bold", name)
    #image("assets/" + code + "employment.svg", width: 100%, alt: name + ": OECD and FRED employment series")
  ])), caption: [Civilian Employment Series])
