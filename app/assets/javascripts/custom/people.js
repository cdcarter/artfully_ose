String.prototype.startsWith = function(str)
{return (this.match("^"+str)==str)}

$(document).ready(function() {
  $("#email-subscription input[type=checkbox]").on("click", function(event) {
    $("#email-subscription input[type=submit]").removeClass("hidden");
  });
  
  $("#person_do_not_email").on("click", function(event) {
    $lists = $(".mail-chimp-list");
    if ($(this).attr("checked") != "checked") {
      $lists.attr("disabled", false);
    } else {
      $lists.attr("checked", false);
      $lists.attr("disabled", true);
    }
  });

  $("input[type=checkbox].mail-chimp-list").on("click", function(event) {
    $target = $(event.target);

    if ($target.attr("checked") != "checked") {
      return;
    }

    event.preventDefault();
    $("#subscribe-modal").modal();
    $("#subscribe-modal .btn-primary").on("click", function(e) {
      $(event.target).attr("checked", "checked");
      $("#subscribe-modal").modal('hide');
    });
  });
  
  var is_star = function(htmlElement) {
    return (htmlElement === "\u272D");
  };

  $(".delete-confirm-link").bind("click", function(event){
    var $dialog = $(this).siblings(".confirmation.dialog").clone(),
        $submit = $(this);

    if($dialog.length !== 0){
      event.preventDefault();
      event.stopImmediatePropagation();
      var $confirmation = $(document.createElement('input')).attr({type: 'hidden', name:'confirm', value: 'true'});
    	var targetUrl = $(this).attr("href");
			var row = $(this).closest("tr")
			var table = row.closest("table")
			var dataTable = table.dataTable()

      $dialog.dialog({
        autoOpen: false,
        modal: true,
        buttons: {
          Cancel: function(){
            $dialog.dialog("close")
          },
          Ok: function(){
            $dialog.dialog("close")
						dataTable.fnDeleteRow( dataTable.fnGetPosition(row.get(0)) );
    				zebra($('.zebra'));
            $.post(targetUrl, {_method:'delete'},
               function(data) {
                 setFlashMessage("The note has been deleted");
               }
            );
          }
        }
      });
      $dialog.dialog("open");
      return false;
    }
  });

  $(".starable").live('click', function() {
    var star      = $.trim($(this).html()),
        person_id = $(this).attr("data-person-id"),
        type      = $(this).attr("data-type"),
        id        = $(this).attr("data-action-id"),
        this_table = $(this).parents('table'),
        this_row   = $(this).parents('tr');

    $.ajax({
       type: "POST",
       url: "/people/" + person_id + "/star/" + type + "/" + id
    });

    if($(this).hasClass('active')) {
      $(this).addClass('not-active');
      $(this).removeClass('active');
      $(this).trigger("unstarred");
    } else {
      $(this).removeClass('not-active');
      $(this).addClass('active');
      $(this).trigger("starred");
    }

    //and re-zebra the table
    zebra(this_table);
  });

  $(".relationship_starred").click(function() {
    var star      = $.trim($(this).html()),
        person_id = $(this).attr("data-person-id"),
        type      = $(this).attr("data-type"),
        id        = $(this).attr("data-action-id"),
        relationship_type  = $.trim($('.relationship_type',this.parent).html()),
        name               = $.trim($('.relationship_person',this.parent).html()),
        relationships_list = $('#key_relationships');

    if(is_star(star)) {
      relationships_list.append("<li id='"+id+"'><div class='key'>"+relationship_type+"</div><div class='value'>"+name+"</div></li>");
    } else {
      $(('#'+id), relationships_list).remove();
    }
  });

  function generateLink(field, $link){
    var href = $(field).html();

    if("Click to edit" !== href && "" !== href){
      $link.html("[ &#9656; ]").attr('target','_blank').appendTo($(field).parent());

      $link.hover(function(){
        if(!href.startsWith("http://")){
          href = "http://" + href;
        }
        $(this).attr("href", href);
      });
    }
  }

  $(".website.value").each(function(){
    var $link = $(document.createElement('a')),
        field = this;

    generateLink(field, $link);

    $(this).bind('done', function(){
      $link.remove();
      generateLink(field, $link);
    });
  });

  $("#mailing-address-form").hide();
  $("#create-mailing-address, #update-mailing-address").bind("click", function(){
    $("#mailing-address").hide();
    $("#mailing-address-form").show();
    $(this).hide();
    return false;
  });

  $("#cancel").bind("click", function(){
    $("#mailing-address-form").hide();
    $("#mailing-address").show();
    $("#create-mailing-address, #update-mailing-address").show();
    return false;
  });

});
