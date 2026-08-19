# Alcalc

<div align="center">

![Alcalc Icon](icons/alcalc.svg)

### Apple Calculator Language (ACL) for Linux & Omarchy

*An expressive array-oriented calculator application and CLI tool inspired by APL, classic Apple Calculator Language, and modern desktop workflows.*

[![Qt 6](https://img.shields.io/badge/Qt-6.11-41CD52.svg?logo=qt&logoColor=white)](https://www.qt.io/)
[![C++17](https://img.shields.io/badge/C++-17-00599C.svg?logo=c%2B%2B&logoColor=white)](https://isocpp.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux%20%7C%20Hyprland-blue.svg)](https://omarchy.org/)

</div>

---

## 🌟 Overview

**Alcalc** is a modern standalone calculator application and CLI evaluator implementing the **Apple Calculator Language (ACL)**. It brings vectorized mathematical calculations, sequence reductions, string transformations, and one-liner algorithmic formulas to the modern Linux desktop with a beautiful Qt 6 / QML interface that automatically matches your system's light/dark theme.

---

## ✨ Features

- 🧮 **Vectorized & Array-Oriented Math:** Calculate across vectors/clumps seamlessly (e.g. `1..100 INSERT +` → `5050`, `32 50 100 212 -32*5/9` → `0 10 37.7778 100`).
- ⚡ **Sequential Left-to-Right Evaluation:** No confusing operator precedence rules (`6/3+2*5` evaluates as `20`; use parentheses `(6/3)+(2*5)` for `12`).
- 🔍 **Step-by-Step Explain Mode:** Inspect the reduction trace of every intermediate calculation step.
- 💡 **Smart Error Assistance:** Friendly diagnosis and 1-click auto-fix suggestions for common syntax mistakes.
- ⌨️ **Keyboard-First REPL:** Immediate autofocus, history navigation with `↑`/`↓` arrow keys, autocompletion with `Tab`, and quick clear/exit with `Esc`.
- 🎛️ **Interactive Operator Toolbar & Keypad:** Quick-insert chips for arithmetic, range generators (`..`), fold reductions (`INSERT`), math monads (`SUM`, `MEAN`, `NORM`, `PRIMES`, `FACT`), string functions, and constants.
- 📜 **Searchable Calculation Tape (History):** Full persistent history with 1-click copy, re-evaluation, and export.
- 📚 **Curated Formula & Sample Library:** Over 40 built-in interactive formulas (Basic arithmetic, sequences, cryptography, parlour tricks, and physics formulas).
- 🧩 **Variables & Custom Macros:** Inspect in-memory variables and create reusable expression templates (e.g. `fahrenheit`: `x - 32 * 5 / 9`).
- 📖 **Built-in Cheatsheet:** Complete syntax and operator reference manual built right into the app.
- 💻 **Fast CLI Tool:** Evaluate expressions directly from your shell (`alcalc "1..100 INSERT +"`, `alcalc --explain "5 TOTHE 2 + 1"`).
- 🎨 **Adaptive Theme Integration:** Dynamically adapts to dark/light mode and desktop font scaling.

---

## 🚀 Installation

### Quick Install (Local User)

Clone the repository and run the installer script:

```bash
git clone https://github.com/jvlianodorneles/alcalc.git
cd alcalc
./install.sh
```

The installer builds the application, places the binary in `~/.local/bin/alcalc`, installs the desktop launcher (`~/.local/share/applications/alcalc.desktop`), installs the vector icon, and registers Alcalc in the application menu.

### Manual Build

#### Requirements
- Qt 6 (`qt6-base`, `qt6-declarative`, `qt6-quickcontrols2`)
- C++17 compiler (`g++` or `clang++`)
- `qmake6` or `cmake`

```bash
# Using QMake
qmake6 alcalc.pro
make -j$(nproc)

# Using CMake
mkdir build && cd build
cmake ..
make -j$(nproc)
```

---

## 💻 CLI Usage

Alcalc can be used directly from the command line for fast calculations and shell scripts:

```bash
# Basic evaluation
alcalc "1..100 INSERT +"
# Output: 5050

# Sequential evaluation
alcalc "6/3+2*5"
# Output: 20

# Vector statistics
alcalc "10 20 30 MEAN"
# Output: 20

# Step-by-step explain mode
alcalc --explain "5 TOTHE 2 + 10"
# Output:
# 🔍 Step-by-Step Evaluation:
#   1. 5 TOTHE 2 = 25
#   2. 25 + 10 = 35
# Final Result: 35

# JSON formatted output
alcalc --json "PI * (5 TOTHE 2)"
```

---

## 📖 Apple Calculator Language (ACL) Crash Course

### 1. Left-to-Right Evaluation
Calculations evaluate strictly from left to right without precedence:
```text
6/3+2*5      ➔ 20    { (6/3 = 2) + 2 = 4; 4 * 5 = 20 }
(6/3)+(2*5)  ➔ 12    { Explicit grouping with parentheses }
```

### 2. Negative Numbers with `_`
In ACL, negative numbers use the underscore `_` prefix without spaces:
```text
_5 + 10      ➔ 5
_45.4 ABS    ➔ 45.4
```

### 3. Clumps, Ranges & Vector Operations
Space-separated numbers form a clump (array vector):
```text
1..5               ➔ 1 2 3 4 5
1..5 * 10          ➔ 10 20 30 40 50
(1 2 3) + (4 5 6)  ➔ 5 7 9
```

### 4. Fold / Reductions (`INSERT`)
Use `INSERT` followed by an operator to fold across a vector:
```text
1..100 INSERT +    ➔ 5050    { Sum of 1 to 100 }
1..5 INSERT *      ➔ 120     { Factorial 5! }
12 85 43 INSERT MAX➔ 85      { Maximum value }
```

### 5. Indexing & Slicing (`[ ]`)
Indexing is 1-based and supports vectors of indices:
```text
"stressed" [8..1]  ➔ desserts
(10 20 30 40)[2 4] ➔ 20 40
```

### 6. Aggregations & Math Monads
```text
10 20 30 SUM       ➔ 60
10 20 30 MEAN      ➔ 20
3 4 NORM           ➔ 5       { Euclidean magnitude sqrt(3^2 + 4^2) }
1..30 PRIMES       ➔ 2 3 5 7 11 13 17 19 23 29
17 PRIME           ➔ 1       { Primality test: 1 (true) / 0 (false) }
12 18 GCD          ➔ 6
4 6 10 LCM         ➔ 60
5 FACT             ➔ 120
64 SQRT            ➔ 8
```

### 7. Variables & Settings
```text
5 : fingers        ➔ Stored variable fingers = 5
fingers * 2        ➔ 10
2 : PLACES         ➔ Changes decimal precision to 2
0 : RADIANS        ➔ Changes angle mode to Degrees (1 = Radians)
ANS * 10           ➔ Multiplies previous answer by 10
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Enter` | Evaluate expression |
| `Shift + Enter` | Evaluate with step-by-step reduction trace (Explain Mode) |
| `↑` / `↓` | Navigate calculation history in input field |
| `Tab` | Autocomplete keyword |
| `Esc` | Clear input (or close application if input is empty) |
| `Ctrl + 1` .. `Ctrl + 5` | Switch between tabs (*Calc*, *Tape*, *Formulas*, *Vars*, *Help*) |
| `Ctrl + L` | Clear input and calculation display |
| `Ctrl + Shift + C` | Copy current result to clipboard |

---

## 🧪 Testing

Run the automated engine test suite using Node.js:

```bash
node --test test/alcalc.test.js
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
