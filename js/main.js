function showTopBar() {
    let country = "France";
    let vat = 20;  // Fixed: Changed from 200 to 20 for tests to pass
    // let vat = 200;
    setTimeout(() => {
        const countryBarElement = document.querySelector("section.country-bar");
        if (countryBarElement) {
            countryBarElement.innerHTML = `<p>Orders to <b>${country}</b> are subject to <b>${vat}%</b> VAT</p>`;
            countryBarElement.classList.remove('hidden');
        }
    }, 1000);
}

// Export function for testing
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { showTopBar };
}

// Auto-execute in browser environment
if (typeof window !== 'undefined') {
    showTopBar();
}
