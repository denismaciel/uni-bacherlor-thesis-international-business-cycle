#import "template.typ": *
#show: thesis

#page(header: none, footer: none)[
  #set text(font: "DejaVu Sans")
  #text(size: 9pt, tracking: 1.4pt, fill: accent)[HUMBOLDT-UNIVERSITÄT ZU BERLIN]
  #v(5pt)
  #text(size: 8.5pt, fill: muted)[School of Business and Economics · Institute for Economic Theory II]
  #v(35mm)
  #text(size: 10pt, tracking: 1.5pt, fill: accent)[BACHELOR’S THESIS / 2015]
  #v(12pt)
  #text(font: "Libertinus Serif", size: 38pt, weight: "bold")[International\ Business Cycles]
  #v(8pt)
  #text(size: 17pt)[Theory and Evidence]
  #v(15pt)
  #line(length: 24mm, stroke: 2pt + accent)
  #v(15pt)
  #text(font: "Libertinus Serif", size: 22pt)[Have the conclusions changed?]
  #v(7pt)
  #text(size: 10pt, fill: muted)[Reassessing Backus, Kehoe and Kydland (1993)]
  #v(1fr)
  #text(size: 13pt, weight: "bold")[Denis Augusto Pinto Maciel]
  #v(4pt)
  #text(size: 9pt, fill: muted)[Student number 505471]
  #v(15pt)
  #text(size: 9pt)[Submitted to Prof. Michael C. Burda, Ph.D.\
  In partial fulfillment of the requirements for the degree of Bachelor of Science]
  #v(13pt)
  #text(size: 9pt)[Berlin, September 5, 2015]
]

#set heading(numbering: none)
#include "chapters/abstract.typ"
#v(12pt)
#include "chapters/acknowledgement.typ"
#v(1fr)
#block(fill: light, inset: 12pt, radius: 2pt)[
  #set text(size: 8.5pt)
  *About this edition.* This Typst edition was prepared in September 2026 from the committed thesis source at `9bef204`. The thesis’s 2015 argument and conclusions are retained; the 2026 research extension is a separate work. Tables 4–7 retain the values and historical comparisons printed in the submitted PDF. Charts are redrawn from the archived thesis data. Layout, citation style, table orientation and figure styling have been modernized.
]
#pagebreak()
#outline(title: [Contents], depth: 2)
#pagebreak()
= Abbreviations
#clean-table(([Code], [Meaning]), (
  ([AUS], [Australia]), ([AUT], [Austria]), ([CAN], [Canada]), ([CHE], [Switzerland]),
  ([DEU], [Germany]), ([EU15], [European aggregate]), ([FRA], [France]), ([GBR], [United Kingdom]),
  ([ITA], [Italy]), ([JPN], [Japan]), ([USA], [United States]),
  ([ACZ], [#cite(<Ambler:2004aa>, form: "prose")]),
  ([BKK / BKK (1993)], [#cite(<Backus:1993aa>, form: "prose")]),
  ([BKK (1992)], [#cite(<Backus:1992aa>, form: "prose")]),
  ([OECD], [Organisation for Economic Co-operation and Development]),
  ([RBC], [Real Business Cycle]),
), columns: (1fr, 4fr), size: 9pt)
#pagebreak()
#outline(title: [Figures], target: figure.where(kind: image))
#v(18pt)
#outline(title: [Tables], target: figure.where(kind: table))
#pagebreak()
#set heading(numbering: "1.1")
#counter(heading).update(0)
#include "chapters/01-introduction.typ"
#pagebreak()
#include "chapters/02-model.typ"
#pagebreak()
#include "chapters/03-data.typ"
#pagebreak()
#include "chapters/04-results.typ"
#pagebreak()
#include "chapters/05-conclusion.typ"
#pagebreak()
#bibliography("references.bib", title: [References])
#pagebreak()
#set heading(numbering: "A.1", supplement: [Appendix])
#counter(heading).update(0)
#include "chapters/measurement-selection.typ"
#pagebreak()
#heading(numbering: none)[Declaration of Authorship]
I hereby confirm that I have authored this Bachelor's thesis independently and without use of others than the indicated sources. All passages which are literally or in general matter taken out of publications or other sources are marked as such.
#v(20pt)
Berlin, September 5, 2015

Denis Augusto Pinto Maciel
