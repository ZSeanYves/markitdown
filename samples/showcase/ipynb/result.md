| Field | Value |
| --- | --- |
| nbformat | 4 |
| nbformat_minor | 1 |
| cells | 24 |
| kernelspec.name | python3 |
| kernelspec.display_name | Python 3 |
| language_info.name | python |
| language_info.version | 3.7.2 |

\[Cell 1 \| markdown\]

# Markdown Cells

\[Cell 2 \| markdown\]

Text can be added to Jupyter Notebooks using Markdown cells.  You can change the cell type to Markdown by using the `Cell` menu, the toolbar, or the key shortcut `m`.  Markdown is a popular markup language that is a superset of HTML. Its specification can be found here:

<https://daringfireball.net/projects/markdown/>

\[Cell 3 \| markdown\]

## Markdown basics

\[Cell 4 \| markdown\]

You can make text \*italic\* or \*\*bold\*\* by surrounding a block of text with a single or double \* respectively

\[Cell 5 \| markdown\]

You can build nested itemized or enumerated lists:

- One
  - Sublist
    - This
  - Sublist
    - That
    - The other thing
- Two
  - Sublist
- Three
  - Sublist

Now another list:

1. Here we go
   1. Sublist
   2. Sublist
2. There we go
3. Now this

\[Cell 6 \| markdown\]

You can add horizontal rules:

---

\[Cell 7 \| markdown\]

Here is a blockquote:

> Beautiful is better than ugly.
> Explicit is better than implicit.
> Simple is better than complex.
> Complex is better than complicated.
> Flat is better than nested.
> Sparse is better than dense.
> Readability counts.
> Special cases aren't special enough to break the rules.
> Although practicality beats purity.
> Errors should never pass silently.
> Unless explicitly silenced.
> In the face of ambiguity, refuse the temptation to guess.
> There should be one-- and preferably only one --obvious way to do it.
> Although that way may not be obvious at first unless you're Dutch.
> Now is better than never.
> Although never is often better than \*right\* now.
> If the implementation is hard to explain, it's a bad idea.
> If the implementation is easy to explain, it may be a good idea.
> Namespaces are one honking great idea -- let's do more of those!

\[Cell 8 \| markdown\]

And shorthand for links:

[Jupyter's website](https://jupyter.org)

\[Cell 9 \| markdown\]

You can use backslash \\ to generate literal characters which would otherwise have special meaning in the Markdown syntax.

```
\*literal asterisks\*
 *literal asterisks*
```

Use double backslash \\ \\ to generate the literal $ symbol.

\[Cell 10 \| markdown\]

## Headings

\[Cell 11 \| markdown\]

You can add headings by starting a line with one \(or multiple\) `#` followed by a space, as in the following example:

```
# Heading 1
# Heading 2
## Heading 2.1
## Heading 2.2
```

\[Cell 12 \| markdown\]

## Embedded code

\[Cell 13 \| markdown\]

You can embed code meant for illustration instead of execution in Python:

def f\(x\): """a docstring""" return x\*\*2

or other languages:

for \(i=0; i\<n; i\+\+\) \{ printf\("hello %d\\n", i\); x \+= 4; \}

\[Cell 14 \| markdown\]

## LaTeX equations

\[Cell 15 \| markdown\]

Courtesy of MathJax, you can include mathematical expressions both inline: $e^\{i\\pi\} \+ 1 = 0$ and displayed:

\\begin\{equation\} e^x=\\sum\_\{i=0\}^\\infty \\frac\{1\}\{i!\}x^i \\end\{equation\}

Inline expressions can be added by surrounding the latex code with `$`:

```
$e^{i\pi} + 1 = 0$
```

Expressions on their own line are surrounded by `\begin{equation}` and `\end{equation}`:

```latex
\begin{equation}
e^x=\sum_{i=0}^\infty \frac{1}{i!}x^i
\end{equation}
```

\[Cell 16 \| markdown\]

## GitHub flavored markdown

\[Cell 17 \| markdown\]

The Notebook webapp supports Github flavored markdown meaning that you can use triple backticks for code blocks:

```python
print "Hello World"
```

```javascript
console.log("Hello World")
```

Gives:

```python
print "Hello World"
```

```javascript
console.log("Hello World")
```

And a table like this:

| This | is |
| --- | --- |
| a | table |

A nice HTML Table:

| This | is |
| --- | --- |
| a | table |

\[Cell 18 \| markdown\]

## General HTML

\[Cell 19 \| markdown\]

Because Markdown is a superset of HTML you can even add things like HTML tables:

<table>
<tr>
<th>Header 1</th>
<th>Header 2</th>
</tr>
<tr>
<td>row 1, cell 1</td>
<td>row 1, cell 2</td>
</tr>
<tr>
<td>row 2, cell 1</td>
<td>row 2, cell 2</td>
</tr>
</table>

\[Cell 20 \| markdown\]

## Local files

\[Cell 21 \| markdown\]

If you have local files in your Notebook directory, you can refer to these files in Markdown cells directly:

\[subdirectory/\]\<filename\>

For example, in the images folder, we have the Python logo:

<img src="../images/python_logo.svg" />

<img src="../images/python_logo.svg" />

and a video with the HTML5 video tag:

<video controls src="../images/animation.m4v">animation</video>

<video controls src="../images/animation.m4v">animation</video>

These do not embed the data into the notebook file, and require that the files exist when you are viewing the notebook.

\[Cell 22 \| markdown\]

### Security of local files

\[Cell 23 \| markdown\]

Note that this means that the Jupyter notebook server also acts as a generic file server for files inside the same tree as your notebooks. Access is not granted outside the notebook folder so you have strict control over what files are visible, but for this reason it is highly recommended that you do not run the notebook server with a notebook directory at a high level in your filesystem \(e.g. your home directory\).

When you run the notebook in a password-protected manner, local file access is restricted to authenticated users unless read-only views are active.

\[Cell 24 \| markdown\]

### Markdown attachments

Since Jupyter notebook version 5.0, in addition to referencing external file you can attach a file to a markdown cell. To do so drag the file from in a markdown cell while editing it:

![pycon-logo.jpg](assets/ipynb-cell24-attachment-pycon-logo-jpg.jpg)

Files are stored in cell metadata and will be automatically scrubbed at save-time if not referenced. You can recognized attached images from other files by their url that starts with `attachment:`. For the image above:

![pycon-logo.jpg](assets/ipynb-cell24-attachment-pycon-logo-jpg.jpg)

Keep in mind that attached files will increase the size of your notebook.

You can manually edit the attachment by using the `View > Cell Toolbar > Attachment` menu, but you should not need to.

![pycon-logo.jpg](assets/ipynb-cell24-attachment-pycon-logo-jpg.jpg)
