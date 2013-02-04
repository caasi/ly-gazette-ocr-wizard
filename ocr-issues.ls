require! GitHubApi: \github

# OCRIssues
#
# This class is inspired by g0v/twlyparser/github.ls, I hope I can update issue
# informations periodically.
#
# TODO:
#   save issue informations locally
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
        # skip empty issues, I think tags should be per-image not per-issue D:
        continue if any (.name is \empty), issue.labels
        title-pattern = /gazette (\d+) \- \d+ images/g
        link-pattern = /\!\[source\/.*\/(.*)\.(.*)\]\(\/\/(.*)\)/g
        if id = title-pattern.exec(issue.title)?[1]
          issue-info =
            id: id
            images: []
          while (links = link-pattern.exec issue.body)?
            issue-info.images.push links{filename: 1, ext: 2, url: 3}
          @issues[issue.number] = issue-info unless issue-info.images.length is 0
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
