require! OCRIssues: \./ocr-issues

requests = {}

ocr = new OCRIssues require \./config-github

do
  meta <- ocr.update
  console.log "[OCRWizard]: got " + ocr.issues.length + " issues"
  main!

main = ->
  require! express
  require! params: \express-params
  app = express!
  params.extend app

  app.set "view engine", \jade
  app.use express.bodyParser!
  app.use express.static __dirname + \/public
  app.param \token /^[0-9A-Fa-f]{40}$/
  app.param \x /\d/
  app.param \y /\d/
  app.param \char /./

  # static pages
  # TODO:
  # figure out how to use express 3 with client-side livescript
  #require! assets: \connect-assets

  do
    req, res <- app.get \/
    res.render \index

  # manual OCR
  require! email: \emailjs/email
  require! config-mail: \./config-mail
  server = email.server.connect config-mail

  do
    req, res <- app.post \/
    # http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
    pattern-email = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
    unless pattern-email.test req.body.mail
      console.log "[MAIL]: " + req.body.mail + " is not a valid email"
      res.send \false
      return
    unless ocr.issues.length
      console.log "[OCRWizard]: yeah! there are no ocr issues, or maybe you should check the connection"
      res.send \false
      return

    # find a random issue with at least one image
    do
      id = (Object.keys ocr.issues)[~~(do Math.random * *)]
    until ocr.issues[id].images.length
    url = ocr.issues[id].images[~~(do Math.random * *)].url

    err, html <- res.render \mail, url: url
    if err?
      console.log "[VIEW]: " + err
      res.send \false
      return

    err, msg <- server.send do
      from: config-mail.user + "@gmail.com",
      to: config-mail.user + "@gmail.com",
      subject: "公報 OCR 小幫手"
      text: "image url: " + url
      attachment:
        * data: html
          alternative: true
        ...
    if err?
      console.log "[MAIL]: " + err
      res.send \false
      return

    console.log "[MAIL]: " + msg
    res.send \true

  # gazette sniper
  require! crypto

  do
    req, res <- app.get \/sniper/target/
    do
      id = (Object.keys ocr.issues)[~~(do Math.random * *)]
    until ocr.issues[id].images.length
    shasum = crypto.createHash "sha1"
    shasum.update do Date.now + issue
    token = shasum.digest \hex # as a key for result
    requests[token] =
      issue: issue
      index: ~~(do Math.random * ocr.issues[id].images.length)
    res.send JSON.stringify token: token, target: ocr.issues[requests[token].issue].images[requests[token].index].url

  do
    req, res <- app.get \/sniper/:token/:x/:y/:char
    if requests[req.params.token]?
      # save result somewhere
      delete requests[req.params.token]
    res.send \true

  # ready to move out
  app.listen 3000
  console.log "[OCRWizard] ready"
