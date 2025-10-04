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
    { back: "#57CC99", font: "black" }, // green light
    { back: "#ffce00", font: "black" }, // yellow
    { back: "#d43545", font: "black" }, // red
    { back: "#ee6c4d", font: "black" }, // orange
    { back: "#1eac53", font: "black" }, // green medium
    { back: "#ffda54", font: "black" }, // yellow light
    { back: "#3f64f8", font: "black" }, // blue
    { back: "#80ED99", font: "black" }, // lime green
    { back: "#f44b6d", font: "black" }, // red light    
    { back: "#C7F9CC", font: "black" }, // light green
    { back: "#ab85d0", font: "black" }, // violet
);

const colorPalettes = {
    african: african,
}



export { colorPalettes };