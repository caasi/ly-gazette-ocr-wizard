require! OCRIssues: \./ocr-issues
config = require \./config

requests = {}

ocr = new OCRIssues require \./config-github

do
  meta <- ocr.update
  console.log "[OCRWizard]: got " + Object.keys(ocr.issues).length + " issues"
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

  # Index Page
  #
  # This is the static page that you ask for a random issue image.
  #
  # TODO:
  #   figure out how to use express 3 with client-side livescript

  #require! assets: \connect-assets

  do
    req, res <- app.get \/
    res.render \index

  # Request Image API
  #
  # Examples:
  #   $curl -F "mail=notamail" http://localhost:3000/ => {"message": "Not a valid email"}
  #   $curl -F "mail=thisisamail@gmail.com" http://localhost:3000/ => true

  require! email: \emailjs/email
  require! config-mail: \./config-mail
  require! crypto
  mail-server = email.server.connect config-mail

  do
    req, res <- app.post \/
    # http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
    pattern-email = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
    unless pattern-email.test req.body.mail
      result =
        message: "Not a valid email"
        more:
          mail: req.body.mail
      console.log result
      res.send JSON.stringify(result{message: message}), 400
      return
    unless ocr.issues.length
      result =
        message: "No issues now"
      console.log result
      res.send JSON.stringify(result{message: message}), 500
      return

    # such an ugly line
    #id = (Object.keys ocr.issues)[~~(do Math.random * *)]
    url = ocr.issues[(Object.keys ocr.issues)[~~(do Math.random * *)]].images[~~(do Math.random * *)].url
    shasum = crypto.createHash \sha1
    shasum.update url + Date.now!
    token = shasum.digest \hex

    requests[token] =
      host: config.host
      token: token
      mail: req.body.mail
      image: url

    err, html <- res.render \mail, requests[token]
    if err?
      result =
        message: "Server error"
        more:
          detail: err
      console.log result
      res.send JSON.stringify(result{message: message}), 500
      return

    err, msg <- mail-server.send do
      from: config-mail.user + \@gmail.com
      to: config-mail.user + \@gmail.com
      subject: "[公報 OCR ] 謝謝您的協助"
      text: "image url: " + url
      attachment:
        * data: html
          alternative: true
        ...
    if err?
      result =
        message: "Server error"
        more:
          detail: err
      console.log result
      res.send JSON.stringify(result{message: message}), 500
      return

    console.log "[MAIL]: an image has already been sent to " + requests[token].mail
    res.send JSON.stringify true

  # Submit Page
  #
  # This is the page that you can submit your OCR result.
  #
  # TODO:
  #   should expired in 10 days
  #   should edit previous result
  do
    req, res <- app.get \/:token
    request = requests[req.params.token]
    if request?
      res.render \submit, request
    else
      result =
        message: "Not found"
        more:
          detail: "unknown token"
      console.log result
      res.send JSON.stringify(result{message: message}), 404

  # Submit API
  #
  # Examples:
  #   $curl -F "result=anarticle" http://localhost:3000/ => true
  do
    req, res <- app.post \/:token
    request = requests[req.params.token]
    if request?
      result = req.body.result
      request.result = result
      err, html <- res.render \result, request
      if err?
        console.log "[VIEW]: " + err
        result =
          message: "Server error"
          more:
            detail: err
        console.log result
        res.send JSON.stringify(result{message: message}), 500
        return
      err, msg <- mail-server.send do
        from: config-mail.user + \@gmail.com
        to: config-mail.user + \@gmail.com
        subject: "[公報 OCR ] 來自 " + request.mail + " 的結果"
        text: "result: " + result
        attachment:
          * data: html
            alternative: true
          ...
      if err?
        result =
          message: "Server error"
          more:
            detail: err
        console.log result
        res.send JSON.stringify(result{message: message}), 500
        return
      console.log "[MAIL]: send result to " + config-mail.user
      res.send \true
    else
      result =
        message: "Not found"
        more:
          detail: "unknown token"
      console.log result
      res.send JSON.stringify(result{message: message}), 404

  # Gazette Sniper
  #
  # This part is deprecated.
  #
  # The original ideal of gazette sniper is to out-sourcing part of the OCR
  # problem to the crowd, you can implement client in your game or as a blog
  # widget, but there is a big problem, I can't evaluate results, I can not
  # get useful information if no one use this service.
  #
  # So I leave it here as a log, maybe someday I will implement it.

  /*
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
  */

  # ready to move out
  app.listen 3000
  console.log "[OCRWizard] ready"
