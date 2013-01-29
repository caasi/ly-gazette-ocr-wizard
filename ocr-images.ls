require \v8-profiler
require! memwatch
require! fs
require! https
require! request
require! OCRIssues: \./ocr-issues

ocr = new OCRIssues require \./config-github
path-images = __dirname + \/images

do
  info <- memwatch.on \leak
  console.log info

meta <- ocr.update
exists <- fs.exists path-images
unless exists
  fs.mkdirSync path-images
for key, issue of ocr.issues
  let path-issue = path-images + \/ + issue.id
    exists <- fs.exists path-issue
    unless exists
      fs.mkdirSync path-issue
    for image, i in issue.images
      let path-image = path-issue + \/ + i + \. + image.ext
        exists <- fs.exists path-image
        unless exists
          err, res, body <- request "https://" + image.url, encoding: \binary
          console.log "[REQUEST]: " + err if err?
          do
            err <- fs.writeFile path-image, body, \binary
            if err?
              console.log "[WRITE]: " + err
            else
              console.log "[WRITE]: " + path-image + " saved"
          err = res = body = null
        else
          console.log "[SKIP]: " + path-image
