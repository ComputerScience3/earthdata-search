do (document, $=jQuery, edsc_date=@edsc.util.date, temporalModel=@edsc.page.query.temporal, plugin=@edsc.util.plugin, page=@edsc.page) ->

  now = new Date()
  today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  current_year = new Date().getUTCFullYear()

  validateTemporalInputs = (root) ->
    start = root.find(".temporal-start:visible")
    end = root.find(".temporal-stop:visible")
    startVal = start.val()
    endVal = end.val()
    if start.hasClass('temporal-recurring-picker')
      # if the input is for recurring, add a year to create a valid date
      startVal = "2000-#{startVal}" if startVal.length > 0
      endVal = "2000-#{endVal}" if endVal.length > 0

    startDate = edsc_date.parseIsoUtcString(startVal)
    endDate = edsc_date.parseIsoUtcString(endVal)

    error = root.find(".tab-pane:visible .temporal-error")
    error.hide()

    if startDate?.toString() == 'Invalid Date' or endDate?.toString() == 'Invalid Date'
      error.show()
      error.text("Invalid date")
    else
      error.hide()

    if !error.is(':visible') and start and end
      error.show()

      if start.hasClass("temporal-recurring-start")
        # Recurring start and stop must both be selected
        if startVal == "" ^ endVal == ""
          error.text("Start and End dates must both be selected")
        else if startVal > endVal
          error.text("Start must be no later than End")
        else
          error.hide()
      else
        if startVal == "" or endVal == "" or startVal <= endVal
          error.hide()
        else
          error.text("Start must be no later than End")

  originalSetDate = null

  $.fn.temporalSelectors = (options) ->
    root = this
    uiModel = options["uiModel"]
    uiModelPath = options["modelPath"]
    prefix = options["prefix"]

    # Sanity check
    console.error "Temporal selectors double initialization" if root.data('temporal-selectors')
    root.data('temporal-selectors', true)

    onChangeDateTime = (dp, $input) ->
      $input.trigger('change')

    root.find('.temporal-range-picker').datepicker
      startDate: "1960-01-01"
      endDate: new Date()
      startView: 2
      todayBtn: "linked"
      clearBtn: true
      autoclose: true
      todayHighlight: true
      forceParse: false
      keyboardNavigation: false


    $('#equatorial-crossing-date-min').datepicker
      format: "yyyy-mm-ddT00:00:00"
      startDate: "1960-01-01"
      endDate: new Date()
      startView: 2
      todayBtn: "linked"
      clearBtn: true
      autoclose: true
      todayHighlight: true
      forceParse: false
      keyboardNavigation: false
      
    $('#equatorial-crossing-date-max').datepicker
      format: "yyyy-mm-ddT23:59:59"
      startDate: "1960-01-01"
      endDate: new Date()
      startView: 2
      todayBtn: "linked"
      clearBtn: true
      autoclose: true
      todayHighlight: true
      forceParse: false
      keyboardNavigation: false
    
    root.find('.temporal-recurring-picker').datepicker(
      startDate: "01-01"
      endDate: "12-31"
      startView: 1
      todayBtn: "linked"
      clearBtn: true
      autoclose: true
      todayHighlight: true
      forceParse: false
      keyboardNavigation: false
      ).on 'show', ->
        $(this).data('datepicker').picker.addClass('datepicker-temporal-recurring')
      

    # Set end time to 23:59:59
    DatePickerProto = if $( ".temporal" ).length then Object.getPrototypeOf($('.temporal').data('datepicker')) else false
    unless originalSetDate?
      originalFill = DatePickerProto.fill
      DatePickerProto.fill = ->
        originalFill.call(this)
        if this.element.hasClass('temporal-recurring-picker')
          field = this.picker.find('.datepicker-days thead .datepicker-switch')
          existingText = field.text()
          field.text(existingText.replace(/\d{4}\s*$/, ''))

    root.find('.temporal-recurring-year-range').slider({
      min: 1960,
      max: current_year,
      value: [1960, current_year],
      tooltip: 'hide'
    }).on 'slide', (e) ->
      uiModel.pending.years(e.value)

    # Set the slider when the years change
    uiModel.pending.years.subscribe (years) ->
      root.find('.temporal-recurring-year-range').slider('setValue', years)

    # Initialize the slider to current value of years
    root.find('.temporal-recurring-year-range').slider('setValue', uiModel.pending.years())

    # Submit temporal range search
    updateTemporalRange = ->
      if root.find('#temporal-date-range .temporal-error').is(":hidden")
        uiModel.apply()
      else
        false

    # Submit temporal recurring search
    updateTemporalRecurring = ->
      if root.find('#temporal-recurring .temporal-error').is(":hidden")
        uiModel.apply()
      else
        false

    root.find('.temporal-submit, .temporal-clear').on 'click', ->
      visible = $(this).parent().siblings(".tab-pane:visible")
      if (visible.is(".temporal-date-range"))
        if updateTemporalRange()
          $(this).parents('.dropdown').removeClass('open')
      else if (visible.is(".temporal-recurring"))
        if updateTemporalRecurring()
          $(this).parents('.dropdown').removeClass('open')

    root.find('.temporal').on 'paste change focusout', (e) ->
      validateTemporalInputs(root)

  $(document).on 'click', '.clear-filters.button', ->
    validateTemporalInputs($('.collection-temporal-filter'))

  $(document).on 'click', '.granule-filters-clear', ->
    validateTemporalInputs($('.granule-temporal-filter'))

  $(document).on 'click', '.temporal-filter .temporal-clear', ->
    validateTemporalInputs($(this).closest('.temporal-filter'))
    # Clear datepicker selection
    $('.temporal-range-start').datepicker('update')
    $('.temporal-range-stop').datepicker('update')

  $(document).ready ->
    # EDSC-1448: If the spatial dropdown is opened, then the temporal dropdown - if open - should close itself...
    $("#spatial-dropdown").on 'click', (e) ->
      $('#temporal-dropdown.open').removeClass('open');

    $('.temporal-filter').on 'click', (e) ->
      e.stopPropagation()
      return  

    # EDSC-1448: .keep-open is a special class for the temporal dropdown - the presence of a datepicker
    # within a dropdown can cause the dropdown to erroneously close when a date is picked.  This prevents that issue.

    $(".dropdown.keep-open").on 'shown.bs.dropdown', (e) ->
      this.closable = false

    $(".dropdown.keep-open").on 'click', (e) ->
      this.closable = true

    $(".dropdown.keep-open").on 'hide.bs.dropdown', (e) ->
      return this.closable
 
    $('.collection-temporal-filter').temporalSelectors({
      uiModel: temporalModel,
      modelPath: "query.temporal.pending",
      prefix: 'collection'
    })

    $('.temporal').keydown (e) ->
      if e.keyCode >= 48 || e.keyCode == 32
        $(this).data('datepicker').hide()
