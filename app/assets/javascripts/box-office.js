//= require "custom/inline-people-search"
//= require_self

function bulletedListItem(person){
  var $li = $("li.template").clone().removeClass("template hidden"),
      $label = $(document.createElement("label")).attr({
        "for": "person_id"
      }).html(person.first_name + " " + person.last_name),
      $radio = $(document.createElement("input")).attr({
        "name":"person_id",
        "type":"radio",
        "value": person.id
      });

  $li.find(".radio").append($radio);
  $li.find(".label").append($label);
  $li.appendTo($(".target"));
}

function showError(message) {
	setErrorMessage(message)
}

function showMessage(message) {
	setFlashMessage(message)
}

function resetPerson() {
	$('.picked-person-clear').html("")
	$('#picket-person-name-in-popup').html("No buyer information")
	$('input#search').val('')	
	$('input#person_id').val('')
}

function resetCommit() {
  $('.ticket-quantity-select').closest("form").find('input[name="commit"]').val('')
}

function resetPayment() {
	$("#payment_method_cash").click()
	$("#credit_card_number").val()
	$("#credit_card_name").val()
	$("#credit_card_month").val($('option:first', $("#credit_card_month")).val())
	$("#credit_card_year").val($('option:first', $("#credit_card_year")).val())
}

function resetQuantites() {
	$.each($('.ticket-quantity-select'), function() {
		$('option[value="0"]', this).attr('selected','selected')
	});	
}

function setPriceDisplay(amountInCents) {
	if (amountInCents > 0) {
		amountInCents = amountInCents / 100;
	}
	$('#total').find('.price').html(amountInCents).formatCurrency();	
	$('#sell-total').find('.price').html(amountInCents).formatCurrency();
}

function resetPrice() {
  setPriceDisplay(0)
  $('.price').removeClass('comped-price');
}

function disableCheckout() {
	$('#checkout-now-button').attr('disabled', true)
	$('#checkout-now-button').addClass('off')
}

function enableCheckout() {
	$('#checkout-now-button').attr('disabled', false)
	$('#checkout-now-button').removeClass('off')
}

function updateQuantities(tickets_remaining) {
  $.each(tickets_remaining, function(section_id, quantity) {
      $('#remaining_' + section_id).html(quantity + ' remaining')
			if (quantity > 0) {
				$('#quantities_' + section_id).removeClass('hidden')
				$('#sold_out_' + section_id).addClass('hidden')
			} else {
				$('#quantities_' + section_id).addClass('hidden')
				$('#sold_out_' + section_id).removeClass('hidden')
			}
  });
}

function ticketsInCart(saleJson) {
  return saleJson.tickets.length > 0
}

$("document").ready(function(){
  
	disableCheckout()
  $("#salesperson-alert").hide();
	
	//People searching stuff is in inline-people-search.js
	
	
  $("#checkout-now-button").click(function(){
    if($("input[name=payment_method]:checked").val() == 'credit_card_swipe') {
      $('#sell-button').hide()
      $('#swipe-now').removeClass('hidden')
      $('#swipe-now').show()
    } else {
      $('#sell-button').show()
      $('#swipe-now').hide()      
    }
    
    $("#sell-popup").modal("show")

    if($("input[name=payment_method]:checked").val() == 'credit_card_swipe') {
	    $("input[name=hack-cc-number]").removeClass("hidden")
	    $("input[name=hack-cc-number]").focus()
    } else {
	    $("#hack-cc-number").addClass("hidden")
	  }

    return false;
  });

  //copy the hack CC number (swiped data) into the actual CC number field
  $("input[name=hack-cc-number]").change(function(){
    $("#credit_card_number").val($("input[name=hack-cc-number]").val())
    form = $('.ticket-quantity-select').closest("form")
    form.find('input[name="commit"]').val('submit')
    $("input[name=hack-cc-number]").val('')
    $("#sell-popup").modal("hide")
    form.submit()
  });

  //Force the hack CC field to never lose focus in an attempt to 
  //ensure the swiped data always lands in the field
  $("input[name=hack-cc-number]").blur(function(){
    setTimeout( function(){ $("input[name=hack-cc-number]").focus(); }, 100 );
  });
  
  $("#cancel-button").click(function(){
    $("#sell-popup").modal("hide")
  });

  $("#sell-button").click(function(){
    form = $('.ticket-quantity-select').closest("form")
	  form.find('input[name="commit"]').val('submit')
	  $("#sell-button").addClass('disabled')
  	$('#sell-button').attr('disabled', true)
	  $('#sell-button').html('Processing...')
	  form.submit()
  });
	
	$('.ticket-quantity-select').on('change', function(){
	   	$(this).closest("form").submit()
	});

	$('.ticket-quantity-select').closest("form")
		.bind("ajax:beforeSend", function(){
    	$("#total").addClass("loading");
    	$("#checkout-now-button").addClass('disabled')
    	$('#checkout-now-button').attr('disabled', true)
			$('.flash').remove()
  	})
		.bind("ajax:failure", function(){
			showError("Sorry, but Artful.ly could not process the payment.  An error report has been recorded.")
			resetPayment()
		})
		.bind("ajax:success", function(xhr, sale){
	   	setPriceDisplay(sale.total)
			$("#total").removeClass("loading");
    		
    	$('input[name="payment_method"]').attr('disabled', !ticketsInCart(sale))
			if (ticketsInCart(sale)) {
				enableCheckout()
			} else {
			  disableCheckout()
			}
			
			$('#popup-ticket-list tbody tr').remove()
	        $.each(sale.tickets, function () {
	          $("#popup-ticket-list").find('tbody')
	            .append($('<tr>')
	              .append($('<td>').html(this.section.name))
	              .append($('<td>').html(this.price / 100).formatCurrency())
	          );         
	        });
  	  $("#checkout-now-button").removeClass('disabled')
  	  $('#checkout-now-button').attr('disabled', false)
	
			$("#sell-popup").modal("hide")
  	  $("#sell-button").removeClass('disabled')
  	  $('#sell-button').attr('disabled', false)
	    $('#sell-button').html('Sell')
	  		
	  	updateQuantities(sale.tickets_remaining)
	  		
			if(sale.sale_made == true) {
  				$.each(sale.door_list_rows, function () {
  					$("#door-list").find('tbody')
  					  .append($('<tr>')
  					    .append($('<td>').html("☐"))
  					    .append($('<td>').html(this.first_name))
  					    .append($('<td>').html(this.last_name))
  					    .append($('<td>').html(this.email))
  					    .append($('<td>').html(this.section))
  					    .append($('<td>').html(this.payment_method))
  					    .append($('<td>').html(this.price / 100).formatCurrency()))
  					  .append($('<tr class="no-border">')
  					    .append($('<td>').html(" "))
  					);         	
  				});
					disableCheckout()
  				resetCommit();
  				resetPayment();
  				resetPerson();
  			  resetQuantites();
  				setPriceDisplay(0);
  				showMessage(sale.message);
  	   		
  			} else if (sale.sale_made == false) {
  				resetPayment();
  			}
			if(sale.error != undefined) {
			  showError(sale.error);
        resetQuantites();
        resetPayment();
		  }
		});

  $(".payment-method").change(function(){
    if($(this).attr('value') != 'credit_card_manual'){
      $("#payment-info").addClass("hidden");
      $("#credit_card_number").val("")
      $("#credit_card_name").val("")
    } else {
      $("#payment-info").removeClass("hidden");
    }

    if($(this).attr('value') == 'credit_card_swipe'){
      $("#salesperson-alert").show();
    } else {
      $("#salesperson-alert").hide();
    }
    
    if($(this).attr('value') == 'comp') { 
      $('.price').addClass('comped-price');
    } else {
      $('.price').removeClass('comped-price');
    }
    
     var payment_method_text = $(this).attr("humanized_value");
     $('#payment-method-popup').html(payment_method_text);
  });
});