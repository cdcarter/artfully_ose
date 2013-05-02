$(document).ready(function(){
  hookupAddToCart()

  $(document).locationSelector({
    'countryField' : '#payment_customer_address_country', 
    'regionField'  : '#payment_customer_address_state'
  });

  // show/hide extended event descriptions
  $('.truncated a.toggle, .not-truncated a.toggle').click(function(e) {
    e.preventDefault();
    $(this).parents('.toggle-truncated').find('.truncated, .not-truncated').toggle();
  });

  // toggle a showing's sections
  $('.title').click(function() {
    $(this).siblings('.sections').slideToggle();
    $(this).toggleClass('active');
  });

  // display the first showing's sections
  $('.title').first().siblings('.sections').slideToggle();
  $('.title').first().addClass('active');

  // when calendar is clicked
  $('td.has_show').click(function() {
    var loadingMessage = $('#loading-container #loading')
    var errorMessage = $('#loading-container #error')
    var date = $(this).attr('data-date');
    var targetLi = $("ul#shows li[data-date='" + date + "']");
    var showUuid = targetLi.attr('data-show-uuid');

    targetLi.hide();

    $.ajax({
      url: "/store/shows/" + showUuid,
      beforeSend: function ( xhr ) {
        //can't use show() because it starts out hidden and show() won't work with that
        errorMessage.css('display', 'none')
        loadingMessage.css('visibility', 'visible')
        
        $("ul#shows li").parent().attr('style','opacity:.4')
      }
    }).done(function ( data ) {
      loadingMessage.css('visibility', 'hidden')
      $("ul#shows li").parent().attr('style','opacity:1')
      $("ul#shows li").hide();  
      targetLi.html(data);  
      targetLi.fadeIn('slow'); 
      hookupAddToCart();
    }).error(function ( data ) {
      loadingMessage.css('visibility', 'hidden')
      errorMessage.css('display', 'block')
      errorMessage.css('visibility', 'visible')
    });
  });


  // click "make donation" button on donation
  $('.add-donation-to-cart').submit(function(e) {
    e.preventDefault();
    donationAmount = $(this).find('#donation_amount').asNumber();
    if (donationAmount > 0) {
      $('#shopping-cart #steps').slideDown(); // not sure why this isn't slideUp
      addItemToCart('donation', {donationAmount: donationAmount});
    }
  });

  $('#discount-link a').click(function(e) {
    e.preventDefault();
    $('tr#discount-link').hide();
    $('tr#discount-display').hide();
    $('tr#discount-input').show();
  });

  $('#discount-input button').click(function(e) {
    e.preventDefault();
    updateOrderOnServer();
  });

  $('#discount-display button').click(function(e) {
    e.preventDefault();
    $('tr#discount-link').hide();
    $('tr#discount-display').hide();
    $('tr#discount-input').show();
  });

  // click "complete purchase" to submit payment
  $('form#shopping-cart-form').submit(function(e) {
    e.preventDefault();
    // dont let people submit form twice
    if (!($('#complete-purchase').hasClass('disabled'))) {
      checkout();
    }
  });

  // show shopping cart when clicked
  $('#shopping-cart-controls').click(function() {
    $('#shopping-cart #steps').slideToggle();
  });

  // add * to required field labels
  $('label.required').append('&nbsp;<strong>*</strong>&nbsp;');

  // switch shopping cart tabs
  $('body').off('click.tab.data-api');
  $('[data-toggle="tab"]').click(function(e) {
    e.preventDefault();
    currentSectionId = $('li.active a').attr('href');
    if (
      !(nextButtonIsDisabled(currentSectionId)) &&
      !(parentIsDisabled(this)) &&
      validateSection(currentSectionId)
    ) {
      switchTabs($(this).attr('href'));
    }
  });

  // click "remove" on a cart item
  $(document).delegate('td.remove a', 'click', function(e) {
    e.preventDefault();
    $(this).parents('tr').remove();
    updateTotal();
    $('.formatCurrency').formatCurrency();
    updateOrderOnServer();
  });

  // change drop down on tickets in cart
  $(document).delegate('#cart select.ticket-count', 'change', function(e) {
    updateQuantityInCart();
    updateTotal();
    $('.formatCurrency').formatCurrency();
    updateOrderOnServer();
  });
});

var hookupAddToCart = function() {
  // click "add to cart" button on tickets
  $('.add-tickets-to-cart').submit(function(e) {
    e.preventDefault();
    $('#shopping-cart #steps').slideDown(); // not sure why this isn't slideUp

    // show the cart tab
    switchTabs('#cart');

    params = {
      sectionId:   $(this).find('#section_id').val(),
      showId:      $(this).find('#show_id').val(),
      sectionName: $(this).find('#section_name').val(),
      ticketCount: parseInt($(this).find('#ticket_count').val(), 10),
      ticketPrice: parseFloat($(this).find('#ticket_price').val()),
      showingName: $(this).find('#showing_name').val()
    };

    addItemToCart('ticket', params);
  });
}

var nextButtonIsDisabled = function(sectionId){
  return $(sectionId+' form-actions a').hasClass('disabled');
};

var parentIsDisabled = function(element){
  return $(element).parent().hasClass('disabled');
};

function updateOrderOnServer() {
  $('#cart .form-actions a').addClass('disabled');
  $('.form-actions #cart-total').hide();
  $('#cart .over-limit').remove();
  var params = {};

  sections = [];
  $('tr.ticket').each(function() {
    sections.push({
      section_id: $(this).attr('data-section-id'),
      show_id: $(this).attr('data-show-id'),
      limit:  $(this).find('.quantity').attr('data-quantity')
    });
  });
  if (sections.length > 0) {
    params.sections = sections;
  }

  donationAmount = parseFloat($('tr.donation td.price').attr('data-price')) * 100;
  if (donationAmount > 0) {
    params.donation = {
      organization_id: organizationId,
      amount: donationAmount
    };
  }

  params.discount = $('#shopping-cart-form #discount').val();

  $.ajax({
    url: sync_store_order_path,
    type: "POST",
    data: params,
    success: function(data) {
      $('#discount-error').html(null);
      // we dont have enough tickets available
      if (data.over_section_limit) {
        jQuery.each(data.over_section_limit, function(index, section) {
          ticket = $("tr.ticket[data-section-id='" + section.section_id + "'][data-show-id='" + section.show_id + "']");
          // change ticket dropdown value
          ticket.find('.quantity select').val(section.limit);
          var message = "";
          if (section.limit === 0) {
            message += "No tickets available for this show's section.";
          } else if (section.limit == 1) {
            message += "Only 1 ticket available for this show's section.";
          } else {
            message += "Only " + section.limit + " tickets available for this show's section.";
          }
          // add error message
          ticket.find('.quantity select').after("<span class='over-limit'><br />" + message + "</span>");
        });
        updateQuantityInCart();
        updateTotal();
        updateRequiredFields();
        hidePaymentDetails();
        $('.formatCurrency').formatCurrency();
      }

      if (data.discount_error) {
        $('#discount-error').html(data.discount_error);
      }

      // add service charge line item
      $('tr#service-charge td.price h5').html(data.service_charge / 100.0);
      $('tr#service-charge td.price').attr('data-price', data.service_charge / 100.0);
      if (data.service_charge > 0) {
        $('tr#service-charge').show();
      } else {
        $('tr#service-charge').hide();
      }

      // add discount line item
      if (data.discount_name) {
        $('tr#discount-link').hide();
        $('tr#discount-input').hide();
        $('tr#discount-display td.details span').html(data.discount_name);
        $('tr#discount-display td.amount h5').html(data.discount_amount / 100.0);
        $('tr#discount-display').show();
      } else {
        $('tr#discount-display').hide();
        $('tr#discount-link').show();
        $('tr#discount-input').hide();
      }
      
      // todo validate amount
      $('.form-actions #cart-total').html(data.total / 100.0);
      $('.form-actions #cart-total').show();

      $('.formatCurrency').formatCurrency();
      
      if(data.tickets.length > 0 || data.donations.length > 0) {
        $('#cart .form-actions a').removeClass('disabled');
      } else {
        $('#cart .form-actions a').addClass('disabled');
      }

    },
    error: function(data) {
      // console.log("updateOrderOnServer: ERROR");
      // console.log(data);
    }
  });
}

function hidePaymentDetails() {
  var total = getTotal();
  if(total > 0) {
    $('#payment-details-fields').removeClass('hidden');
    $('#payment-details-message').addClass('hidden');
  } else {
    $('#payment-details-fields').addClass('hidden');
    $('#payment-details-message').removeClass('hidden');
  }
}

function updateRequiredFields() {
  var total = getTotal();
  $('input.nonzero-total').each(function() {
    if(cartTotal > 0) {
      $(this).addClass('required');
      $(this).removeAttr("disabled");
    } else {
      $(this).removeClass('required');
      $(this).attr("disabled", "disabled");
    }
  });
}

function getTotal() {
  cartTotal = $('.form-actions #cart-total').html();
  if (cartTotal === undefined || cartTotal === "") {
    return 0;
  } else if (cartTotal.indexOf('$') > -1){
    return cartTotal.split('$')[1];
  } else {
    return cartTotal;
  }
}

function updateQuantityInCart() {
  $('#cart select.ticket-count').each(function() {
    ticketCount = parseInt($(this).val(), 10);
    sectionId = $(this).parents('tr').attr('data-section-id');
    showId = $(this).parents('tr').attr('data-show-id');
    unitPrice = $(this).parent('td').attr('data-unit-price');

    $(this).parent('td').attr('data-quantity', ticketCount);
    subTotal = parseFloat(unitPrice) * ticketCount;
    $(this).parents('tr').find('td.price').attr('data-price', subTotal);
    $(this).parents('tr').find('td.price h5').text(subTotal);
  });
}

function checkout() {
  // POST "/store/checkout" // Store::CheckoutsController#create as HTML // Parameters: {"utf8"=>"✓", "authenticity_token"=>"oGmh5IrGv6CU3aPbpERHFNTpZg6YAiwLXY66d0zev6I=", "athena_payment"=>{"athena_customer"=>{"first_name"=>"test", "last_name"=>"test", "phone"=>"test", "email"=>"test@test.com"}, "athena_credit_card"=>{"cardholder_name"=>"test test", "card_number"=>"4242424242424242", "cvv"=>"123", "expiration_date(3i)"=>"1", "expiration_date(2i)"=>"2", "expiration_date(1i)"=>"2015"}, "billing_address"=>{"street_address1"=>"test", "city"=>"test", "state"=>"AL", "postal_code"=>"12345"}, "user_agreement"=>"1"}, "confirmation"=>"1", "commit"=>"Purchase"}
  $('#complete-purchase').addClass('disabled');

  // make sure agreement checkbox is checked
  if ($('#agreement-checkbox').is(':checked')) {
    $('#purchase .error').hide();
    $.ajax({
      type: 'POST',
      url: store_checkout_path,
      data: $("form#shopping-cart-form").serialize(),
      success: function(data) {
        $('#nav').hide();
        $('.tab-pane').hide();
        $('.tab-pane#thanks').show();
      },
      error: function(data) {
        $('#nav li').removeClass('active');
        $('.tab-pane').hide();
        $('.tab-pane#result').show();
        $('.tab-pane#result').html("<h4>Your payment did not go through.</h4><p>" + data.responseText + "</p>");
        $('#complete-purchase').removeClass('disabled');
      }
    });
  } else {
    // have to add this error message manually for some reason
    $('#purchase .error').show();
    $('#complete-purchase').removeClass('disabled');
  }
}

function switchTabs(newSectionId) {
  $('#nav li').removeClass('active');
  var listElement = $('li a[href="' + newSectionId + '"]').parent('li');
  listElement.addClass('active');
  listElement.removeClass('disabled');
  $('.tab-pane').hide();
  $(newSectionId+'.tab-pane').show();
}

// validate fields inside a shopping cart tab
// return true if everything valid, false otherwise
// add error classes and labels if its invalid
function validateSection(sectionId) {
  var everythingValid = true;
  $(sectionId + ' input.required').each(function() {
    v = $('#shopping-cart-form').validate({
      errorElement: "span",
      errorClass:'help-inline',
      highlight: function(element, errorClass) {
        $(element).parents('.control-group').addClass('error');
      },
      unhighlight: function(element, errorClass) {
        $(element).parents('.control-group').removeClass('error');
      }
    }).element("#" + $(this).attr('id'));
    if (!(v)) {everythingValid = false;}
  });
  return everythingValid;
}

function addItemToCart(type, params) {
  if (type === 'ticket') {
    // if exisiting line item for this secion and show, dont add it again
    var existing_line_items = $("[data-section-id='" + params.sectionId + "'][data-show-id='" + params.showId + "']").size() > 0;
    if (!existing_line_items) {
      createTicketLineItem(params);
    }
    
  } else if (type === 'donation') {
    createOrUpdateDonationLineItem(params);
  }

  updateTotal();
  $('.formatCurrency').formatCurrency();
  updateOrderOnServer();
}

function createTicketLineItem(params) {
  $('#cart table').prepend(
    "<tr class='ticket' data-section-id='" + params.sectionId + "' data-show-id='" + params.showId + "'>" +
      "<td class='remove'><a href='#'>remove</a></td>" +
      "<td class='details'>" +
        "<h5>" + params.sectionName + " ticket</h5>" +
        eventName + "<br />" +
        params.showingName +
      "</td>" +
      "<td class='quantity' data-quantity='" + params.ticketCount + "' data-unit-price='" + params.ticketPrice + "'>" +
        "<select class=\"ticket-count\" id=\"tickets__count\" name=\"tickets[][count]\"><option value=\"0\">0 Tickets<\/option>\n<option value=\"1\">1 Ticket<\/option>\n<option value=\"2\">2 Tickets<\/option>\n<option value=\"3\">3 Tickets<\/option>\n<option value=\"4\">4 Tickets<\/option>\n<option value=\"5\">5 Tickets<\/option>\n<option value=\"6\">6 Tickets<\/option>\n<option value=\"7\">7 Tickets<\/option>\n<option value=\"8\">8 Tickets<\/option>\n<option value=\"9\">9 Tickets<\/option>\n<option value=\"10\">10 Tickets<\/option><\/select>" +
        "<br /><span class='formatCurrency'>" + params.ticketPrice + "</span> each" +
        "<input id='section_id' name='tickets[][section_id]' type='hidden' value='" + params.sectionId +"'>" +
      "</td>" +
      "<td class='price' data-price='" + (params.ticketPrice * params.ticketCount) + "'>" +
        "<h5 class='formatCurrency'>" +
          (params.ticketPrice * params.ticketCount) +
        "</h5>" +
      "</td>" +
    "</tr>"
  );

  $("[data-section-id='" + params.sectionId + "'][data-show-id='" + params.showId + "'] .ticket-count").val(params.ticketCount);
}

function createOrUpdateDonationLineItem(params) {
  $('#cart table tr.donation').remove();
  $('#cart table').prepend(
    "<tr class='donation'>" +
      "<td class='remove'><a href='#'>remove</a></td>" +
      "<td class='details'><h5>Donation</h5></td>" +
      "<td class='quantity'></td>" +
      "<td class='price' data-price='" + params.donationAmount + "'>" +
        "<h5 class='formatCurrency'>" + params.donationAmount + "</h5>" +
      "</td>" +
    "</tr>"
  );
}

function updateTotal() {
  total = 0;
  $('[data-price]').each(function() {
    total += parseFloat($(this).attr('data-price'));
  });
  $('.form-actions #cart-total').html(total);
}
