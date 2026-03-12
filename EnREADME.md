# TrancyKeyboardMac

**A bilingual IME that lets you learn English while typing Chinese.**

TrancyKeyboardMac is an innovative input method that deeply integrates **English learning with a Chinese IME**.
It records the words you select during typing and automatically generates personalized review content, allowing you to naturally understand and accumulate English vocabulary while typing.

This approach enables true **“Learn While Typing”**.

The input method supports **mixed Chinese-English input**, without requiring manual switching between languages. When typing letters, the system simultaneously matches **Chinese Pinyin candidates** and **English word candidates**.

For example, typing:

```
she
```

will display candidates like:

```
射       蛇      she   sheep
shoot   snake    她    羊
```

Users can type Chinese or English directly while also confirming spelling and understanding word meanings during the typing process.

Through a **dual-layer candidate system and bilingual candidate display**, TrancyKeyboardMac naturally integrates typing behavior with vocabulary learning, allowing users to accumulate vocabulary while chatting, writing, or working — enabling a truly **effortless learning experience**.

---

# Core Features

## 1. Mixed Chinese–English Input

Supports **mixed input of Pinyin and English words** without switching input modes.

When typing letters, the system simultaneously matches:

* Chinese Pinyin candidates
* English word candidates

For example:

```
she → 射 / 蛇 / she / sheep
```

This design seamlessly combines Chinese typing with English learning, achieving true **Typing = Learning**.

---

## 2. English-to-Chinese Lookup & Pinyin Trigger

### English-to-Chinese Lookup

Users can input **English words directly to find Chinese candidates**.

Example:

```
apple → 苹果
```

This allows users to reinforce spelling during daily typing, gradually building **muscle memory for vocabulary**.

### Pinyin Trigger

If users remember the Chinese pronunciation but forget the English word, typing the **Pinyin** will automatically trigger related English candidates.

Example:

```
pingguo → apple
```

This solves the common problem of **remembering the Chinese meaning but forgetting the English word**.

---

## 3. Bilingual Candidates & Output

During letter input, the candidate bar **displays both Chinese and English words simultaneously**.

Users can choose according to their needs:

* Type Chinese for daily communication
* Output English directly for work or study

With **bilingual candidate comparison**, users naturally understand word meanings during typing, enabling **learning while using**.

---

## 4. Fuzzy Matching & Smart Correction

To improve typing tolerance, the system includes multiple intelligent correction mechanisms.

### English Fuzzy Matching

Supports spelling tolerance and typo correction, for example:

```
frind → friend
woke → work / wake
```

Even with incomplete spelling or key offset errors, the system can accurately predict the intended word.

### Pinyin Fuzzy Matching

Supports common Pinyin fuzzy rules:

```
zh ↔ z
ch ↔ c
an ↔ ang
en ↔ eng
```

Keyboard mis-touches can also be automatically corrected.

---

## 5. Large Vocabulary & Translation Support

Built-in multi-layer vocabulary system:

* **280k+ Chinese words**
* **20k+ high-frequency English words**
* **20k+ semantic phrase blocks**
* **50k+ common English sentences**
* **70k+ Chinese–English dictionary entries**

Combined with the **Apple system translation dictionary**, users can download the translation dictionary on first use.

Supported features include:

* Filling missing English vocabulary
* Quick word lookup
* Long sentence translation

Helping users quickly understand vocabulary during typing.

---

## 6. Advanced Typing Experience

### Slide Typing

Supports **continuous slide typing** without tapping individual keys.
Even if the sliding path is slightly inaccurate, the system can intelligently recognize the intended input.

### Multiple Input Schemes

Supported input methods:

* Full Pinyin (26-key)
* Xiaohe Shuangpin

**iOS also supports:**

* 9-key Pinyin
* Stroke input

### Highly Customizable Settings

Users can freely configure:

* Candidate display layers (single-layer or translation display)
* Candidate priority order
* English lookup and auto-suggestion
* Fuzzy English spelling
* Chinese lookup, emoji lookup, symbol lookup
* Automatic word composition and frequency adjustment
* Fuzzy Pinyin and Pinyin correction
* Slide typing
* Keyboard height
* Keyboard theme colors
* Font size
* Key sound effects
* Haptic feedback

Allowing users to create a typing experience that perfectly fits their preferences.

---

# Download PKG

### 1. Download the latest release

```
https://github.com/kindnessskl/TrancykeyboardMac/releases
```

### 2. Run the installer

```
TrancyKeyboard.pkg
```

### 3. Restart the computer or log out

This refreshes the macOS input method cache.

### 4. Open System Settings

```
Keyboard
→ Input Sources → Edit
→ Click "+"
→ Simplified Chinese
→ TrancyKeyboard
→ Add
```

### 5. Enable the input method and start using it.

---

# Platform Versions

### macOS

This repository corresponds to the **macOS version**:

* Fully open-source
* Free to use

### iOS

The **iOS version** is a paid app available on the App Store (¥10):

[https://apps.apple.com/cn/app/%E4%B8%AD%E8%8B%B1%E8%BE%93%E5%85%A5%E6%B3%95/id6756459946](https://apps.apple.com/cn/app/%E4%B8%AD%E8%8B%B1%E8%BE%93%E5%85%A5%E6%B3%95/id6756459946)

Includes:

* Full feature set
* Word selection history
* Vocabulary learning system

---

# Open Source License & Version Differences

This project is released under the **GPL-3.0 License**.

## Source Code & Database

All **frontend and logic layer source code** are open-source.
However, to protect the ecosystem and certain data copyrights, the **core vocabulary database is not fully open-source**.

The macOS version uses an **encrypted database**.

## Version Differences

* **macOS Version:** Fully open-source and free to use.
* **iOS Version:** Paid version with complete built-in features and vocabulary database.

---

# Acknowledgements

TrancyKeyboard was developed with inspiration from the following open-source projects and datasets:

* **Rime-ice (雾凇拼音)**
  [https://github.com/iDvel/rime-ice](https://github.com/iDvel/rime-ice)

* **WordFrequency / COCA**
  [https://www.wordfrequency.info](https://www.wordfrequency.info)
  [https://www.english-corpora.org/coca/](https://www.english-corpora.org/coca/)

* **TypeDuck**
  [https://github.com/TypeDuck-HK/TypeDuck-Mac](https://github.com/TypeDuck-HK/TypeDuck-Mac)

* **Tatoeba**
  [https://tatoeba.org](https://tatoeba.org)

* **hallelujahIM**
  [https://github.com/dongyuwei/hallelujahIM](https://github.com/dongyuwei/hallelujahIM)

* **squirrel**
  [https://github.com/rime/squirrel](https://github.com/rime/squirrel)

* **talisman**
  [https://github.com/Yomguithereal/talisman](https://github.com/Yomguithereal/talisman)

* **MDCDamerauLevenshtein**
  [https://github.com/modocache/MDCDamerauLevenshtein](https://github.com/modocache/MDCDamerauLevenshtein)

Thanks to all open-source contributors.

---

# License

This project is licensed under the **GNU General Public License v3.0**.

See the [LICENSE](LICENSE) file for details.

---

# Demo

```
![demo1](demo/demo1.jpg)
![demo2](demo/demo2.jpg)
![demo3](demo/demo3.jpg)
![demo4](demo/demo4.jpg)
![demo5](demo/demo5.jpg)
![demo6](demo/demo6.jpg)
![demo7](demo/demo7.jpg)
![demo8](demo/demo8.jpg)
![demo9](demo/demo9.jpg)
![demo10](demo/demo10.jpg)
![demo11](demo/demo11.jpg)
```

---


