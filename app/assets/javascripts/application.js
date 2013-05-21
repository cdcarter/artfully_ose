//= require jquery
//= require jquery_ujs
//= require jquery-lib
//= require locationselector
//= require_directory ./custom
//= require bootstrap
//= require_self

zebra = function(table) {
    $("tr", table).removeClass("odd");
    $("tr", table).removeClass("even");
    $("tr:even", table).addClass("even");
    $("tr:odd", table).addClass("odd");
};

bindControlsToListElements = function () {
  $(".detailed-list li").hover(
    function(){
      $(this).find(".controls").stop(false,true).fadeIn('fast');},
    function(){
      $(this).find(".controls").stop(false,true).fadeOut('fast');});
};

function createErrorFlashMessage(msg) {
	$('#heading').after($(document.createElement('div'))
							.addClass('flash')
							.addClass('error')
							.addClass('alert')
							.addClass('alert-error')
							.html('<span>'+msg+'</span>'));

	$(".close").click(function(){
		$(this).closest('.flash').remove();
	});
}

function setErrorMessage(msg) {
	if($('.flash').length > 0) {
		$('.flash').fadeOut(400, function() {
			$(this).remove();
			createErrorFlashMessage(msg);
		});
	} else {
		createErrorFlashMessage(msg);
	}
}

function createFlashMessage(msg) {
	$('#heading').after($(document.createElement('div'))
							.addClass('flash')
							.addClass('success')
							.addClass('alert')
							.addClass('alert-info')
							.html('<span>'+msg+'</span>'));

	$(".close").click(function(){
		$(this).closest('.flash').remove();
	});
}

function setFlashMessage(msg) {
	if($('.flash').length > 0) {
		$('.flash').fadeOut(400, function() {
			$(this).remove();
			createFlashMessage(msg);
		});
	} else {
		createFlashMessage(msg);
	}
}

function bindEditOrderLink() {
  $("#edit-order-link, .edit-order-link").bind("ajax:complete", function(et, e){
    $("#edit-order-popup").html(e.responseText);
    $("#edit-order-popup").modal( "show" );
    activateControls();
    touchCurrency();
    return false;
  });
}

function singleShot() {
  $(".single-shot").parents("form").submit(function(){
    $(this).find(".single-shot").attr('disabled','disabled');
  });
}

function returnFalse() {
  return false;
}

$(document).ready(function() {
    
	/*********** NEW BOOTSTRAP JS ***********/
	$(".alert").alert();

  $('.email-popup').popover({trigger:'manual'})
                   .click(function(){ $(this).popover('toggle'); });

  if($.browser.mozilla) {
    $('.section-price-disabled *').css("pointer-events", "none");
  }

	$('.help').popover();
	$('.edit-message, .delete-message').popover({title: "Editing / Deleting", content: "We can only edit or delete manually entered donations.", placement: "right"});
	
	$('.dropdown-toggle').dropdown();
	
	$('#nag').modal('show');

  $('.dropdown .dropdown-menu .disabled').on('click', function(e) {
    e.preventDefault();
  });
	
	/*********** NEW ARTFULLY JS ************/
  
  $('.artfully-tooltip').tooltip();
	
	/*********** EXISTING ARTFUL.LY JS ******/

  singleShot();

  $(document).locationSelector({
    'countryField' : '#person_address_attributes_country',
    'regionField'  : '#person_address_attributes_state'
  });

  $("form .description").siblings("input").focusin(function(){
    $("form .description").addClass("active");
  }).focusout(function(){
    $("form .description").removeClass("active");
  });

  $(".zebra tbody").each(function(){
    zebra($(this));
  });

  $(".close").click(function(){
    $(this).closest('.flash').remove();
  });

  $(".new-window").parents("form").attr("target", "_blank");

  $("#main-menu").hover(
    function(){$("#main-menu li ul").stop().animate({height: '160px'}, 'fast');},
    function(){$("#main-menu li ul").stop().animate({height: '0px'}, 'fast');}
  );

  $(".stats-controls").click(function(){
    $(this).parent("li").toggleClass("selected");
    $(this).siblings(".hidden-stats").slideToggle("fast");
    return false;
  });

  activateControls();

  $(".new-performance-link").click(function() {
    $("#new-performance-row").show();
    return false;
  });

  $(".cancel-new-performance-link").click(function() {
    $("#new-performance-row").hide();
    return false;
  });

  $(".checkall").click(function(){
    var isChecked = $(this).is(":checked");
    $(this).closest('form').find("input[type='checkbox']:enabled").each(function(index, element){
      element.checked = isChecked;
      $(element).change();
    });
  });

  $(".zebra tbody").each(function(){
    zebra($(this));
  });

  $(".search-help-popup").dialog({autoOpen: false, draggable:false, modal:true, width:700, title:"Search help"});
  $("#search-help-link").click(function(){
    $(".search-help-popup").dialog("open");
    return false;
  });

  $(".add-new-ticket-type-link").bind("ajax:complete", function(et, e){
    $("#newTicketType").html(e.responseText);
    $("#newTicketType").modal( "show" );
    return false;
  });

  $("#bulk-action-link").bind("ajax:complete", function(et, e){
    $("#bulk-action-modal").html(e.responseText);
    $("#bulk-action-modal").modal( "show" );
    activateControls();
    return false;
  });

  $('.new-action-save').click(returnFalse())
  $('.action-type-button').click(function(){
    $('.new-action-save').off();
  })

  $(".new-action-link").click(function(){
    $('.new-action-form').toggle();
    return false;
  });

  $('.action-type button').click(function() {
    type = $(this).attr('data-action-type');
    form = $(this).parents('form');
    $('#action_type').val(type);
    $('#artfully_action_details').attr('placeholder', $(this).attr('data-details-placeholder'));
    $("#artfully_action_details").removeAttr("disabled");
    var subtypes = eval($(this).attr('data-subtypes'));
    $('#artfully_action_subtype').empty();

    if (subtypes.length > 0) {
      $('#artfully_action_subtype').show();
      $.each(subtypes, function(index, value) {   
        $('#artfully_action_subtype')
          .append($("<option></option>")
          .attr("value",value)
          .text(value));
      });
    } else {
      $('#artfully_action_subtype').hide();
    }

    if (type === 'give') {
      form.find('.dollar-inputs').show();
    } else {
      form.find('.dollar-inputs').hide();
    }

    $('#artfully_action_details').focus();
    return true;
  })

  bindEditOrderLink()

  $(".edit-note-link").click(function(){
    $(this).parents('tr').find('td').hide();
    $(this).parents('tr').find('.edit-note-form').show();
    $(this).parents('tr').find('.edit-note-form textarea').focus();
    return false;
  });

  $(".new-note-link").click(function(){
    $('.new-note-form').toggle();
    $('.new-note-form textarea').focus();
    return false;
  });

  $('table#notes-list').on("click", 'td.toggle-truncated .truncated, td.toggle-truncated .not-truncated', function(event) {
    $(this).parent().find('div').toggle();
  })

  $('table#action-list').on("click", 'td.toggle-truncated .truncated, td.toggle-truncated .not-truncated', function(event) {
    $(this).parent().find('div').toggle();
    bindEditOrderLink()
  })

  $('table#action-list').on("click", 'a.edit-action-link', function(event) {
    event.stopPropagation(); // dont toggle truncated
    event.preventDefault();  // dont follow link
    $(this).parents('tr').find('td').hide();
    $(this).parents('tr').find('.edit-action-form').show();
    $(this).parents('tr').find('.edit-action-form textarea').focus();
  })

  $('.action-form').on("click", 'a.action-form-cancel-link', function(event) {
    $(this).parents('tr').find('td').show();
    $(this).parents('.action-form').hide();
    $(this).parents('.modal').modal( "hide" );
    return false;
  })

  $('#more-notes-link').toggle(function() {
    $('#more-notes').toggle();
    $('#more-notes-link .triangle').html('&#9662;');
  },
  function() {
    $('#more-notes').toggle();
    $('#more-notes-link .triangle').html('&#9656;');
  });

  var eventId = $("#calendar").attr("data-event");
  var resellerEventId = $("#calendar").attr("data-reseller-event");
  var organizationId = $("#calendar").attr("data-organization");
  if (eventId !== undefined) {
    $('#calendar').fullCalendar({
      height: 500,
      events: '/events/' + eventId + '.json',
      eventClick: function(calEvent, jsEvent, view){
        window.location = '/events/'+ eventId + '/shows/' + calEvent.id;
      }
    });
  } else if (resellerEventId !== undefined && organizationId !== undefined) {
    $('#calendar').fullCalendar({
      height: 500,
      events: '/organizations/' + organizationId + '/reseller_events/' + resellerEventId + '.json'
    });
  }
  $('#tabs').tabs({
      show: function(event, ui) {
          $('#calendar').fullCalendar('render');
      }
  });

  $('.tag.deletable').each(function() {
		createControlsForTag($(this));
  });

  $(".new-tag-form").bind("ajax:beforeSend", function(evt, data, status, xhr){
		tagText = validateTag()
    if(!tagText) { return false; }
    $(this).hide();
    newTagLi = $(document.createElement('li'));
		newTagLi.addClass('tag').addClass('deletable').addClass('rounder').html(tagText);
    $('.tags li:last').before(newTagLi);
    $('.tags li:last').before("\n");
		createControlsForTag(newTagLi);
    $('#new-tag-field').attr('value', '');

		bindControlsToListElements();
		bindXButton();
  });

  bindControlsToListElements();
  bindXButton();

  $(".delete").bind("ajax:beforeSend", function(evt, data, status, xhr){
    $(this).closest('.tag').remove();
  });

  $(".super-search").bind("ajax:complete", function(evt, data, status, xhr){
      $(".super-search-results").html(data.responseText);
      $(".super-search-results").removeClass("loading");
  }).bind("ajax:beforeSend", function(){
    $(".super-search-results").addClass("loading");
  });

  $('.editable .value').each(function(){
    var url = $(this).attr('data-url'),
        name = $(this).attr('data-name');

    $(this).editable(url, {
      method: "PUT",
      submit: "OK",
      cssclass: "jeditable form-inline",
      height: "15px",
      width: "150px",
      name: "person[" + name + "]",
      callback: function(value, settings){
        $(this).html(value[name]);
        $(this).trigger('done');
      },
      ajaxoptions: {
        dataType: "json"
      }
    });
  });

});



bindXButton = function() {
  $(".delete").bind("ajax:beforeSend", function(evt, data, status, xhr){
    $(this).closest('.tag').remove();
  });
};


validateTag = function() {
  var tagText = $('#new-tag-field').attr('value');
  if(!validTagText(tagText)) {
    $('.tag-error').text("Only letters, number, or dashes allowed in tags");
    return false;
  } else {
    $('.tag-error').text("");
    $('li.tag.new-tag').show();
    return tagText;
  }
}

/*
 * Validates alphanumeric and -
 */
validTagText = function(tagText) {
	var alphaNumDashRegEx = /^[0-9a-zA-Z-]+$/;
	return alphaNumDashRegEx.test(tagText);
};

createControlsForTag = function(tagEl) {
	var tagText = tagEl.html().trim();
	var subjectName = tagEl.parent("ul").attr('id').split("-")[0];
	var subjectId = tagEl.parent("ul").attr('id').split("-")[1];

	var deleteLink = '<a href="/'+subjectName+'/'+ subjectId +'/tag/'+ tagText +'" data-method="delete" data-remote="true" rel="nofollow">X</a>';
	var controlsUl =  $(document.createElement('ul')).addClass('controls');
	var deleteLi = $(document.createElement('li')).addClass('delete').append(deleteLink);

	controlsUl.append(deleteLi);

  tagEl.append(controlsUl);
	tagEl.append("\n");
};

function touchCurrency() {
  $(".currency").each(function(index, element){
		$(this).focus()
		$(this).maskMoney('mask')
	});
}

function activateControls() {
  $(".currency").each(function(index, element){
    var name = $(this).attr('name'),
        input = $(this),
        form = $(this).closest('form'),
        hiddenCurrency = $(document.createElement('input'));

    input.maskMoney({showSymbol:true, symbolStay:true, allowZero:true, symbol:"$"});
    input.attr({"id":"old_" + name, "name":"old_" + name});
    hiddenCurrency.attr({'name': name, 'type': 'hidden'}).appendTo(form);

    form.submit(function(){
      hiddenCurrency.val(Math.round( parseFloat(input.val().substr(1).replace(/,/,"")) * 100 ));
    });
  });

  $(".datepicker" ).datepicker({dateFormat: 'yy-mm-dd'});
	if (!Modernizr.inputtypes.date) {
		$('input[type="date"]').datepicker({
      dateFormat: 'yy-mm-dd'
    });
	}

  $('.datetimepicker').datetimepicker({dateFormat: 'yy-mm-dd', timeFormat:'hh:mm tt', ampm: true });
  if (!Modernizr.inputtypes.datetime) {
    $('input[type="datetime"],input[type="datetime-local"]').datetimepicker({
      dateFormat: 'yy-mm-dd',
      timeFormat:'hh:mm tt',
      ampm: true
    });
  }
	
  
}

function togglePrintPreview(){
    var screenStyles = $("link[rel='stylesheet'][media='screen']"),
        printStyles = $("link[rel='stylesheet'][href*='print']");

    if(screenStyles.get(0).disabled){
      screenStyles.get(0).disabled = false;
      printStyles.attr("media","print");
    } else {
      screenStyles.get(0).disabled = true;
      printStyles.attr("media","all");
  }
}
