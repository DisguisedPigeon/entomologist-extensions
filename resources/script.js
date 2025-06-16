function copy(identifier) {
    const content = document.getElementById(identifier).textContent;
    navigator.clipboard.writeText(content);
    alert('Copied ' + content)
}
