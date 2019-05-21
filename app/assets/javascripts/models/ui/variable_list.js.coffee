# = require models/data/variables

ns = @edsc.models.ui

ns.VariableSelector = do (ko
                    window
                    $ = jQuery
                    ajax = @edsc.util.xhr.ajax
                    VariablesModel = @edsc.models.data.Variables
                    QueryModel = @edsc.models.data.query.CollectionQuery) ->

  keywordLevels = ['Category', 'Topic', 'Term', 'VariableLevel1', 'VariableLevel2', 'VariableLevel3', 'DetailedVariable']

  class VariableSelector
    constructor: (@project) ->
      @selectedCollection = ko.observable(null);
      @selectedProjectCollection = ko.observable(null)
      @variables = ko.asyncComputed([], 100, @_retrieveVariables, this, deferEvaluation: true)
      @selectedKeyword = ko.observable(null)
      @keywordMappings = ko.computed(@_computeKeywordMappings, this, deferEvaluation: true)
      @selectedVariable = ko.observable(null);

      @_pending = ko.observable(null)

      @query = new QueryModel()

      $(document).ready(@_onReady)

    _onReady: =>
      # Select All Checkbox
      $(document).on 'click', '.select-all', (e) =>
        if @selectedKeyword()
          isSelected = $(e.target).is(':checked')

          $('.collection-variables input[type="checkbox"]').prop('checked', isSelected)


    ###*
     * Determine whether or not the currently selected keyword has all of its variables selected
     ###
    hasAllKeywordsSelected: =>
      for variable in @selectedKeyword().variables
        # Return false if ANY of the variables are not selected
        return false unless @selectedProjectCollection().hasSelectedVariable(variable)
      true

    ###*
     * Determine the number of variables that are selected, and within the provided list.
     ###
    _countSelectedVariables: (listToCheck) ->
      count = 0
      for variable in listToCheck
          if @selectedProjectCollection().indexOfSelectedVariable(variable) != -1
            count++
      count

    ###*
     * Determine the number of variables that are selected in total.
     ###
    _countAllSelectedVariables: (listsToCheck) ->
      count = 0
      count += @_countSelectedVariables(listsToCheck)
      count

    ###*
     * Retrieves a variable object provided a concept id
     ###
    _getVariable: (concept_id) =>
      for variable in @variables()
        if concept_id == variable.meta()['concept-id']
          return variable
      null

    ###*
     * Writes the currently selected variables to the observable
     ###
    _saveSelectedVariableState: =>
      # Pull out the selected variables before we wipe them below
      selectedVariables = $('.collection-variables input[type="checkbox"]:checked')

      # Rather than keeping a delta within each keyword mapping, we'll just delete all
      # selected variables within the currently selected keyword and re-add them below
      for mapping in @keywordMappings()
        if mapping.keyword == @selectedKeyword().keyword
          @selectedProjectCollection().selectedVariables.remove (variable) =>
            variable in @selectedKeyword().variables

      # Add each of the selected variables (pulled out above) to the project collection
      selectedVariables.each (index, element) =>
        selectedVariableId = $(element).val()

        @selectedProjectCollection().selectedVariables.push(@_getVariable(selectedVariableId))

      # Sends the user back to the keyword list
      @clearKeyword()

    ###*
     * Creates the full navigation structure used in displaying variables grouped by their ScienceKeywords
     ###
    _computeKeywordMappings: =>
      calculatedMappings = {}

      for variable in @variables()
        for keyword in variable.umm()?.ScienceKeywords || []
          keywordPath = $.grep((keyword[keywordLevel] for keywordLevel in keywordLevels), Boolean)

          leafNode = keywordPath.pop()
          if !calculatedMappings.hasOwnProperty(leafNode)
            calculatedMappings[leafNode] = []

          calculatedMappings[leafNode].push(variable)

      # Return an array of objects for easier digest from the view instead of doing it in the view
      keywords = []
      for keyword, variables of calculatedMappings
        variables = variables.sort (a, b) ->
          x = a.umm().Name
          y = b.umm().Name
          return -1 if x < y
          return 1 if x > y
          0

        keywords.push {
          keyword: keyword,
          selected: @_countSelectedVariables(variables),
          variables: variables }

      keywords.sort (a, b) ->
        x = a.keyword
        y = b.keyword
        return -1 if x < y
        return 1 if x > y
        0

    ###*
     * Pings CMR for full variable metadata for each variable associated with the selectedCollection
     ###
    _retrieveVariables: =>
      # TODO: Move to Collection Model?
      if @selectedCollection()
        # Retreive the variable ids assigned to the collection
        variableIds = @selectedCollection()?.associations()?['variables']

        # Prevent making unnecessary requests
        if variableIds
          @_pending(true)
          VariablesModel.forIds variableIds, @query, (variables) =>
            @variables(variables)
            @_pending(false)

    ###*
     * Saves the currently selected variables and project
     ###
    saveState: (selectedKeyword, e) =>
      @_saveSelectedVariableState()
      $(window).trigger('edsc.save_workspace')

    ###*
     * Sets the currently selected keyword
     ###
    selectKeyword: (selectedKeyword, e) =>
      @selectedKeyword(selectedKeyword)

    ###*
     * Clears the currently selected keyword
     ###
    clearKeyword: (selectedKeyword, e) =>
      @selectedKeyword(null)

    ###*
     * Sets the currently selected variable. This will trigger the variable detail screen
     ###
    selectVariable: (selectedVariable) =>
      @selectedVariable(selectedVariable)

    ###*
     * Clears the currently selected variable
     ###
    clearVariable: =>
      @selectedVariable(null)

    ###*
     * Clears all current selections
     ###
    clearSelections: =>
      @clearKeyword()
      @clearVariable()

    ###*
     * Assign a variable to a nested navigation structure
     * @param {object} Collection object assigned to the card this modal was initiated from
     ###
    displayVariableSelector: (projectCollection) =>
      projectCollection.triggerEditVariables()
      @selectedCollection(projectCollection.collection)
      @selectedProjectCollection(projectCollection)

    ###*
     * Cleanup obversables
     ###
    wipeObservables: =>
      @selectedKeyword(null)

      # Wipe the variables to prevent a different collections
      # data from flashing when presented
      @variables([])

  exports = VariableSelector
