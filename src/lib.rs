use unicode_segmentation::UnicodeSegmentation;
use wasm_bindgen::prelude::*;

trait StrExt {
    fn is_whitespace(&self) -> bool;
}

impl StrExt for str {
    fn is_whitespace(&self) -> bool {
        self.chars().all(char::is_whitespace)
    }
}

#[wasm_bindgen]
pub fn generate_numeronym(input: &str) -> String {
    let graphemes: Vec<String> = input
        .graphemes(true)
        .filter(|g| !g.is_whitespace())
        .map(|g| g.to_lowercase())
        .collect();

    match graphemes.len() {
        0..=2 => graphemes.concat(),
        len => format!(
            "{}{}{}",
            graphemes.first().map(String::as_str).unwrap_or(""),
            len - 2,
            graphemes.last().map(String::as_str).unwrap_or("")
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_well_known_examples() {
        assert_eq!(generate_numeronym("localization"), "l10n");
        assert_eq!(generate_numeronym("internationalizatoin"), "i18n");
        assert_eq!(generate_numeronym("accessibility"), "a11y");
        assert_eq!(generate_numeronym("observability"), "o11y");
    }

    #[test]
    fn test_well_known_example_with_uppercase() {
        assert_eq!(generate_numeronym("Andreessen Horowitz"), "a16z");
    }

    #[test]
    fn test_trimming() {
        assert_eq!(generate_numeronym("shorten"), "s5n");
        assert_eq!(generate_numeronym("   shorten"), "s5n");
        assert_eq!(generate_numeronym("shorten    "), "s5n");
        assert_eq!(generate_numeronym(" shorten "), "s5n");
        assert_eq!(generate_numeronym("    shorten "), "s5n");
    }

    #[test]
    fn test_case_handling() {
        assert_eq!(generate_numeronym("tomato"), "t4o");
        assert_eq!(generate_numeronym("Tomato"), "t4o");
        assert_eq!(generate_numeronym("TOMATO"), "t4o");
        assert_eq!(generate_numeronym("TomatO"), "t4o");
    }

    #[test]
    fn test_non_ascii_characters() {
        assert_eq!(generate_numeronym("Győző"), "g3ő");
        assert_eq!(generate_numeronym("Álmos"), "á3s");
    }

    #[test]
    fn test_emojis() {
        assert_eq!(generate_numeronym("a😂c"), "a1c");
        assert_eq!(generate_numeronym("a😂😂"), "a1😂");
        assert_eq!(generate_numeronym("😂😂😂"), "😂1😂");
        assert_eq!(generate_numeronym("🍏👩🏻‍🔬👌🏾"), "🍏1👌🏾");
    }

    #[test]
    fn test_short_inputs() {
        assert_eq!(generate_numeronym(""), "");
        assert_eq!(generate_numeronym("a"), "a");
        assert_eq!(generate_numeronym("ab"), "ab");
        assert_eq!(generate_numeronym("abc"), "a1c");
    }
}
