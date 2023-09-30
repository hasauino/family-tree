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
const colorPalettes = {
    nature: getPalette({ back: "#CCD5AE", font: "black" }, { back: "#E9EDC9", font: "black" }, { back: "#FEFAE0", font: "black" }, { back: "#FAEDCD", font: "black" }, { back: "#D4A373", font: "black" }),
    sunset: getPalette({ back: "#FFCDB2", font: "black" }, { back: "#FFB4A2", font: "black" }, { back: "#E5989B", font: "black" }, { back: "#B5838D", font: "white" }, { back: "#6D6875", font: "white" }),
    iceCream: getPalette({ back: "#D8E2DC", font: "black" }, { back: "#FFE5D9", font: "black" }, { back: "#FFCAD4", font: "black" }, { back: "#F4ACB7", font: "black" }, { back: "#9D8189", font: "white" }),
    modern: getPalette({ back: "#3d5a80", font: "white" }, { back: "#98c1d9", font: "black" }, { back: "#e0fbfc", font: "black" }, { back: "#ee6c4d", font: "black" }, { back: "#293241", font: "white" }),
    african: getPalette({ back: "#1eac53", font: "black" }, { back: "#ffce00", font: "black" }, { back: "#d43545", font: "black" }, { back: "#ee6c4d", font: "black" }, { back: "#293241", font: "white" }),
    reddish: getPalette({ back: "#F7B267", font: "white" }, { back: "#F79D65", font: "black" }, { back: "#F4845F", font: "black" }, { back: "#F27059", font: "black" }, { back: "#F25C54", font: "black" }),
    greenish: getPalette({ back: "#22577A", font: "white" }, { back: "#38A3A5", font: "white" }, { back: "#57CC99", font: "black" }, { back: "#80ED99", font: "black" }, { back: "#C7F9CC", font: "black" }),
    mango: getPalette({ back: "#233D4D", font: "white" }, { back: "#FE7F2D", font: "white" }, { back: "#FCCA46", font: "black" }, { back: "#A1C181", font: "black" }, { back: "#619B8A", font: "white" }),
}


export { colorPalettes };