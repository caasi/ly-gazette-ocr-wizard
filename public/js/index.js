(function() {
  $submit = $("#submit");
  $mail = $("#mail");
  $loading = $("<i class=\"icon-spinner icon-spin\"></i>");
  $success = $("<i class=\"icon-ok\"></i>");
  $fail = $("<i class=\"icon-warning-sign\"></i>");

  $mail.focus(function(e) {
    $submit.
      attr("disabled", false).
      text("給我公報圖片");
  });

  $submit.click(function(e) {
    e.preventDefault();

    $submit.
      html($loading).
      attr("disabled", true);

    $.post("/", { mail: $mail.val() }).
      done(function(result) {
        $submit.html($success);
        console.log(result);
      }).
      fail(function(xhr) {
        $submit.html($fail);
        console.log(JSON.parse(xhr.responseText));
      });
  });
}($));
