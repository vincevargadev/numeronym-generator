import init, { generate_numeronym } from './pkg/numeronym_generator.js';

async function main() {
    // Initialize the WASM module
    await init();

    // Grab input field and result div
    const inputField = document.getElementById('input-field');
    const resultDiv = document.getElementById('result');

    // Add an event listener for input changes
    inputField.addEventListener('input', () => {
        const inputValue = inputField.value;
        const numeronym = generate_numeronym(inputValue);
        resultDiv.innerHTML = `<p>${numeronym}</p>`;
    });
}

main();
