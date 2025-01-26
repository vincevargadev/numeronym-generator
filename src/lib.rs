use unicode_segmentation::UnicodeSegmentation;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn generate_numeronym(input: &str) -> String {
    let trimmed = input.trim().to_lowercase();
    let no_spaces: String = trimmed.chars().filter(|c| !c.is_whitespace()).collect();
    let graphemes: Vec<&str> = no_spaces.graphemes(true).collect();
    let len = graphemes.len();
    if len <= 2 {
        return no_spaces;
    }

    let first = graphemes.first().unwrap_or(&"");
    let last = graphemes.last().unwrap_or(&"");
    let numeronym = format!("{}{}{}", first, len - 2, last);

    numeronym
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
