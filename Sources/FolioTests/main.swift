// Test runner entry point. Add new suites here as they are written.
print("Running FolioCore tests…\n")

print("FileKind:")
runFileKindTests()

print("\nHiddenFlag:")
runHiddenFlagTests()

print("\nMarkdownRenderer:")
runMarkdownRendererTests()

print("\nLinkPolicy:")
runLinkPolicyTests()

print("\nAppearance:")
runAppearanceTests()

print("\nPreviewHTML:")
runPreviewHTMLTests()

print("\nImageInliner:")
runImageInlinerTests()

print("\nDelimitedText:")
runDelimitedTextTests()

print("\nPreviewMode:")
runPreviewModeTests()

print("\nFileTreeLoader:")
runFileTreeLoaderTests()

print("\nFileFilter:")
runFileFilterTests()

print("\nAllURLs:")
runAllURLsTests()

print("\nPreviewZoom:")
runPreviewZoomTests()

print("\nBoundedLoad:")
runBoundedLoadTests()

print("\nNodeFinder:")
runNodeFinderTests()

print("\nFileOperations:")
runFileOperationsTests()

print("\nHiddenFiles:")
runHiddenFilesTests()

T.summarize()
