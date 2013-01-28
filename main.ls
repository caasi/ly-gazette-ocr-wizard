requests = {}

require! GitHubApi: \github
github = new GitHubApi version: \3.0.0
github.authenticate require \./config-github

# inspired by g0v/twlyparser/github.ls
class OCRIssues
  issues: []
  last-update: 0
  update: (cb) ->
    next = (err, res) ~>
      if err?
        console.log "[GITHUB]: " + err
        return
      console.log "[GITHUB]: request a page of issues"
      for issue in res
        title-pattern = /gazette (\d+) \- \d+ images/g
        link-pattern = /\!\[source\/.*\/(.*)\.(.*)\]\(\/\/(.*)\)/g
        if id = title-pattern.exec(issue.title)?[1]
          @issues[issue.number] =
            id: id
            images: []
          while (links = link-pattern.exec issue.body)?
            @issues[issue.number].images.push links{filename: 1, ext: 2, url: 3}
      if github.has-next-page res
        github.get-next-page res, next
      else
        @last-update = Date.now!
        cb res.meta
    github.issues.repoIssues {
      user: \g0v
      repo: \ly-gazette
      labels: \OCR
      state: \open
      sort: \created
      direction: \asc
      per_page: 100
    }, next

issues = new OCRIssues

do
  meta <- issues.update
  console.log "[OCRWizard]: got " + issues.issues.length + " issues"
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
    console.log req.body
    # find a random issue with at least one image
    do
      issue = (Object.keys pages)[~~(do Math.random * *)]
    until pages[issue].images.length
    url = pages[issue].images[~~(do Math.random * *)].url

    err, html <- res.render \random, url: url
    if err?
      console.log "[VIEW]: " + err
      res.send \false
      return

    err, msg <- server.send do
      from: config-mail.user + "@gmail.com",
      to: config-mail.user + "@gmail.com",
      subject: "test mail"
      text: "image url: " + url
      attachment: [
        data: html
        alternative: true
      ]
    if err?
      console.log "[MAIL]: " + err
      res.send \false
      return

    console.log msg
    res.send \true

  # gazette sniper
  require! crypto

  do
    req, res <- app.get \/sniper/target/
    do
      issue = (Object.keys pages)[~~(do Math.random * *)]
    until pages[issue].images.length
    shasum = crypto.createHash "sha1"
    shasum.update do Date.now + issue
    token = shasum.digest \hex # as a key for result
    requests[token] =
      issue: issue
      index: ~~(do Math.random * pages[issue].images.length)
    res.send JSON.stringify token: token, target: pages[requests[token].issue].images[requests[token].index].url

  do
    req, res <- app.get \/sniper/:token/:x/:y/:char
    if requests[req.params.token]?
      # save result somewhere
      delete requests[req.params.token]
    res.send \true

  # ready to move out
  app.listen 3000
  console.log "[OCRWizard] ready"
