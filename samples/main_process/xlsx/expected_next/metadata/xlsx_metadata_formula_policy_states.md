## FormulaPolicy

| Case | Expression | Value |
| --- | --- | --- |
| Cached formula | 10+5 | 15 |
| Evaluated missing cache | 1+2 | =1+2 |
| Unsupported formula | VLOOKUP(1,A1:B3,2,FALSE) | =VLOOKUP(1,A1:B3,2,FALSE) |
| Formula error | 1/0 | =1/0 |
