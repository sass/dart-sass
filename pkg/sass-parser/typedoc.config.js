/** @type {import('typedoc').TypeDocOptions} */
module.exports = {
  entryPoints: ["./lib/index.ts"],
  highlightLanguages: ["cmd", "dart", "dockerfile", "js", "ts", "sh", "html"],
  out: "doc",
  navigation: {
    includeCategories: true,
  },
  hideParameterTypesInTitle: false,
  categorizeByGroup: false,
  categoryOrder: [
    "Statement",
    "Expression",
    "Other",
  ]
};
