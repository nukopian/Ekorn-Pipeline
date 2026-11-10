# Planned work

## 1. Keep short sections, and code with its introduction, in the PDFs

**From:** DBIx-Squirrel's session, 2026-11-10 (DBIx-Squirrel
caa8137467fb714dbae3c05c6758bbefec7b4e22)
**Waiting on:** nothing

**What:** Iain found ugly page breaks in DBIx-Squirrel's PDFs, and
asked that Ekorn-Pipeline's get the same fix. Its `docs/print.css` and
`scripts/readme-pdf.sh` are the same as DBIx-Squirrel's were, but for
Ekorn's own `blockquote` rule, so the fix carries over as it is. Three
kinds of break were fixed:

- a short section split across two pages;
- a code block on the page after the sentence that introduces it,
  ending with a colon;
- a paragraph's last line alone at the top of a page.

**Steps:**

1. In `scripts/readme-pdf.sh`, give pandoc `--section-divs`, so each
   section is wrapped in a `<section class="levelN">`:

   ```
   pandoc "$1" --from gfm --standalone --section-divs --metadata pagetitle="${title:-README}" \
   ```

2. In `docs/print.css`, the rule starting each chapter on a page moves
   from the `h2` to its section, as each `h2` is now first in a
   section of its own, so `h2:first-of-type` would match them all. In
   place of the `h2 { break-before: page; ... }` and
   `h2:first-of-type` rules:

   ```css
   section.level2 ~ section.level2 {
     break-before: page;
   }
   h2 {
     string-set: section content();
   }

   /* Keep a short subsection whole: one that would be split across a page
      break starts on the next page. One taller than a page still breaks. */
   section.level3 {
     break-inside: avoid;
   }

   /* Keep a code block with the paragraph that introduces it, and never leave
      one line of a paragraph alone at the foot or head of a page. */
   pre {
     break-before: avoid;
   }
   p, li {
     orphans: 2;
     widows: 2;
   }
   ```

   DBIx-Squirrel's `docs/print.css` at the commit above has them in
   place.
3. Build the PDFs, and check them. Each chapter should still start a
   page. Look at every page with ImageMagick, which Iain has
   installed (`pdftoppm -r 30 -png X.pdf p` then
   `magick montage p-*.png -tile 8x -geometry +4+4 sheet.png`). Then
   check every break: no page should end with a line ending in a colon,
   and none should start mid-sentence, other than with a heading that
   starts with a code name. `pdftotext -layout -f N -l N` gives each
   page's lines.

In DBIx-Squirrel, the README and MAINTAINING kept their page counts,
and the how-to and the reference gained one page each. None of the
three kinds of break was left.

**Done when:** the PDFs are built with the change, every chapter starts
a page, and no break of the three kinds is left.
