# Vendored Summernote assets

The Summernote Lite assets in this directory come from the official
Summernote **v0.9.1** distribution release:

- Release: https://github.com/summernote/summernote/releases/tag/v0.9.1
- Archive: `summernote-0.9.1-dist.zip`
- Archive SHA-256: `cf62f6ddbfbee4f6a7fd47433a2414a3d8ec5c6a4d6a4f08151548af1d6ef99e`

Vendored files and upstream SHA-256 checksums:

- `summernote-lite.min.js`: `584d79169efb7ab0b91acaa00b34e83aaa2fedbcaf912a48b73da4a947c97a47`
- `summernote-lite.min.css`: `de26528812c62b0cd48fd776a22905acbe7de8cf02e993da8542c5e45e310010`
- `font/summernote.eot`: `a7142d8f69aa5e027938fe74eb1e09adf4a8872e408e7ffa7624cf10c36c94cc`
- `font/summernote.ttf`: `8c19737f49862a8e5a7f3e9b09b5e33a5a00d096466eb458176e98893e07e52b`
- `font/summernote.woff`: `f9d40b380e26ea6c1f579dd47ec28da9c8eb414882651e0adba199bb31f8cc62`
- `font/summernote.woff2`: `9c7cb1a4e1341ce24398f7742ca9ea3014dac38829aaa0cc2d0c74a8195915de`

Project-specific dark-mode and Flutter integration behavior remains outside the
upstream minified assets so future upgrades can replace them byte-for-byte.
