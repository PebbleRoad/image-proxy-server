Image Proxy Server
==================
Image proxy server will take an image and resize it to two specific sizes: 160x237 and 320x474.

Usage
-----
URL should have the size and the URL that you want to resize. For example:

`/image/160x237/http%3A%2F%2Fallon.it%2Fwp-content%2Fuploads%2F2015%2F02%2Fgatt.jpg`

Example for SC:

`http://domain.com/sc/375x175/https%3A%2F%2Fwww.sc.com%2Fsg%2Fassets%2Fpws%2Fimages%2Fbanner%2F1580x350_sme_banking.jpg`
`http://192.168.2.11/sc/375x175/https%3A%2F%2Fwww.sc.com%2Fsg%2Fassets%2Fpws%2Fimages%2Fbanner%2F1580x350_sme_banking.jpg`

`http://52.76.132.44/sc/375x175/<country>/https%3A%2F%2Fwww.sc.com%2Fsg%2Fassets%2Fpws%2Fimages%2Fbanner%2F1580x350_sme_banking.jpg`

Don't forget to URL encode the path to the source image.

Dependancies
------------
This requires [GraphicsMagick](http://www.graphicsmagick.org/) with the JPG library. For Mac, [follow this](http://ext.raneous.net/post/40106080462/building-graphicsmagick-on-osx) and download version 9a. Probably the same for *nix.

Refs:
-----
http://ext.raneous.net/post/40106080462/building-graphicsmagick-on-osx

http://stackoverflow.com/questions/20220899/graphicsmagick-no-decode-delegate-for-this-image-format

http://justinbozonier.posthaven.com/creating-an-image-proxy-server-in-nodejs

Notes
-----
Originally used an AMI that's in the US West (N. California) region. AMI ID: ImageProxy (ami-3c85ad79). [Source here](https://github.com/eahanson/imageproxy).