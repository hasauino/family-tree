function getPalette(...colors) {
    let palette = {}
    for (const [index, color] of colors.entries()) {
        palette[`g${index}`] = {
            color: { background: color.back, border: color.back, hover: { background: color.back, border: color.back }, highlight: { background: color.back, border: color.back } },
            font: { color: color.font },
        };
    }
    return palette
}

const african = getPalette(
    { back: "#57CC99", font: "black" },
    { back: "#ffce00", font: "black" },
    { back: "#d43545", font: "black" },
    { back: "#ee6c4d", font: "black" },
    { back: "#1eac53", font: "black" },
    { back: "#ffda54", font: "black" },
    { back: "#3f64f8", font: "black" },
    { back: "#80ED99", font: "black" },
    { back: "#C7F9CC", font: "black" },
    { back: "#f44b6d", font: "black" },
);

const colorPalettes = {
    african: african,
}



export { colorPalettes };