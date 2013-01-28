require! GitHubApi: \github

# inspired by g0v/twlyparser/github.ls
class OCRIssues
  (auth) ->
    @auth = auth
    @github = new GitHubApi version: \3.0.0
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
      if @github.has-next-page res
        @github.get-next-page res, next
      else
        @last-update = Date.now!
        cb res.meta
    @github.authenticate @auth
    @github.issues.repoIssues {
      user: \g0v
      repo: \ly-gazette
      labels: \OCR
      state: \open
      sort: \created
      direction: \asc
      per_page: 100
    }, next

module.exports = exports = OCRIssues
