# Image service
So this is supposed to work as simply as possible, so images in a directory.

The name of the image should be the sha256 of the image.

the metadata of the image including source, base tags and anything else should be in a json file under the
the same sha256 of the image .json

If the sha256.json of an image exists then merge them, source uris need to be an array for this reason

The "images" can also be symlinks.

## Raw image service
The main api requires a sha of the image so it doesnt work if we don't have the image.

It also doesn't work if your images arent named for their own sha... so we need a tool to rename the image once we have it

the raw image service will do both of these, it will probably be three different services but working off a directory as not a service is a bit easier to start.