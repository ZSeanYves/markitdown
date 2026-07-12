\\documentclass\{article\}

| Field | Value |
| --- | --- |
| title | An Example Document |
| author | Leslie Lamport |
| date | January 21, 1994 |

```tex
\newcommand{\ip}[2]{(#1, #2)}
```

```tex
\begin{document}             % End of preamble and beginning of text.
```

\\maketitle

This is an example input file.  Comparing it with the output it generates can show you how to produce a simple document of your own.

# Ordinary Text

The ends  of words and sentences are marked by   spaces. It  doesn't matter how many spaces    you type; one is as good as 100.  The end of   a line counts as a space.

One   or more   blank lines denote the  end of  a paragraph.

Since any number of consecutive spaces are treated like a single one, the formatting of the input file makes no difference to \\LaTeX, but it makes a difference to you.  When you use \\LaTeX, making your input file as easy to read as possible will be a great help as you write your document and when you change it.  This sample file shows how you can add comments to your own input file.

Because printing is different from typewriting, there are a number of things that you have to do differently when preparing an input file than if you were just typing the document directly. Quotation marks like \`\`this'' have to be handled specially, as do quotes within quotes: \`\`\\,\`this' is what I just wrote, not  \`that'\\,''.

Dashes come in three sizes: an intra-word dash, a medium dash for number ranges like 1--2, and a punctuation dash---like this.

A sentence-ending space should be larger than the space between words within a sentence.  You sometimes have to type special commands in conjunction with punctuation characters to get this right, as in the following sentence. Gnats, gnus, etc.\\ all begin with G\\@. You should check the spaces after periods when reading your output to make sure you haven't forgotten any special cases.  Generating an ellipsis \\ldots\\

with the right spacing around the periods requires a special command.

\\LaTeX\\ interprets some common characters as commands, so you must type special commands to generate them.  These characters include the following: \\$ \\& \\% \\\# \\\{ and \\\}.

In printing, text is usually emphasized with an \\emph\{italic\} type style.

> Environment: Em
A long segment of text can also be emphasized
   in this way.  Text within such a segment can be
   given \emph{additional} emphasis.

It is sometimes necessary to prevent \\LaTeX\\ from breaking a line where it might otherwise do so. This may be at a space, as between the \`\`Mr.''\\ and \`\`Jones'' in \`\`Mr.~Jones'', or within a word---especially when the word is a symbol like \\mbox\{\\emph\{itemnum\}\} that makes little sense when hyphenated across lines.

Footnotes\\footnote\{This is an example of a footnote.\} pose no problem.

\\LaTeX\\ is good at typesetting mathematical formulas like \\\( x-3y \+ z = 7 \\\) or \\\( a\_\{1\} \> x^\{2n\} \+ y^\{2n\} \> x' \\\) or \\\( \\ip\{A\}\{B\} = \\sum\_\{i\} a\_\{i\} b\_\{i\} \\\). The spaces you type in a formula are ignored.  Remember that a letter like $x$ is a formula when it denotes a mathematical symbol, and it should be typed as one.

# Displayed Text

Text is displayed by indenting it from the left margin.  Quotations are commonly displayed.  There are short quotations

> This is a short quotation.  It consists of a
   single paragraph of text.  See how it is formatted.

and longer ones.

> This is a longer quotation.  It consists of two
   paragraphs of text, neither of which are
   particularly interesting.

   This is the second paragraph of the quotation.  It
   is just as dull as the first paragraph.

Another frequently-displayed structure is a list. The following is an example of an \\emph\{itemized\} list.

```tex
\begin{itemize}
```

- This is the first item of an itemized list. Each item in the list is marked with a \`\`tick''. You don't have to worry about what kind of tick mark is used.
- This is the second item of the list. It contains another list nested inside it. The inner list is an \emph{enumerated} list.

```tex
\begin{enumerate}
```

1. This is the first item of an enumerated list that is nested within the itemized list.
2. This is the second item of the inner list. \LaTeX\ allows you to nest lists deeper than you really should.

```tex
\end{enumerate}
```

This is the rest of the second item of the outer list.  It is no more interesting than any other part of the item.

- This is the third item of the list.

```tex
\end{itemize}
```

You can even display poetry.

> There is an environment
    for verse \\             % The \\ command separates lines
   Whose features some poets % within a stanza.
   will curse.

                             % One or more blank lines separate stanzas.

   For instead of making\\
   Them do \emph{all} line breaking, \\
   It allows them to put too many words on a line when they'd rather be
   forced to be terse.

Mathematical formulas may also be displayed.  A displayed formula is one-line long; multiline formulas require special formatting instructions. \\\[  \\ip\{\\Gamma\}\{\\psi'\} = x'' \+ y^\{2\} \+ z\_\{i\}^\{n\}\\\] Don't start a paragraph with a displayed equation, nor make one a paragraph by itself.

```tex
\end{document}               % End of document.
```
