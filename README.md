# ConCaT

**Concatenate and filter files easily, with the path for the file in the middle.**

## Features

- Concatenate all files in the current directory or specify multiple patterns (e.g., `*.c *.h *.py`).
- Default output file if none given.
- Optional descriptions and interactive mode.

## Installation

1. Copy `concat` into a directory in your `$PATH` (e.g., `~/bin`):
   ```bash
   cp concat ~/bin
   chmod +x ~/bin/concat
   ```

2. Ensure `~/bin` is in your `$PATH`. Add this to your `~/.bashrc` or `~/.zshrc`:
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```

3. Reload your shell:
   ```bash
   source ~/.bashrc
   ```
   
   *(Adjust `.bashrc` to `.zshrc` or other shell config if needed.)*

## Usage

- Concatenate `.c` and `.h` files into `myoutput.txt`:
  ```bash
  concat *.c *.h myoutput.txt
  ```

- Concatenate all `.py` files to the default output (`concat.o`):
  ```bash
  concat *.py
  ```

- Interactive mode:
  ```bash
  concat -i
  ```
  Then type a pattern (e.g., `*.sh`) or `all`.

- Add descriptions:
  ```bash
  concat -d *.txt all_texts.o
  ```

## Alias Example

If you prefer shorter commands, add this line to your shell config (`.bashrc`, `.zshrc`, etc.):

```bash
alias ccat='concat'
```

Then simply:

```bash
ccat *.f90 final_code.o
```

No need for quotes or multiple pattern flags—just type and go!
