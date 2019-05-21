#= require models/data/query
#= require models/data/collections
#= require models/data/collection
#= require models/data/variables
#= require models/data/colors

ns = @edsc.models.data

ns.Project = do (ko,
                 document
                 $ = jQuery
                 extend = $.extend
                 param = $.param
                 deparam = @edsc.util.deparam
                 ajax = @edsc.util.xhr.ajax
                 urlUtil = @edsc.util.url
                 QueryModel = ns.query.CollectionQuery
                 CollectionsModel = ns.Collections
                 VariablesModel = ns.Variables
                 ServiceOptionsModel = ns.ServiceOptions
                 ColorsModel = ns.Colors
                 Collection = ns.Collection
                 QueryParam = ns.QueryParam
                 page = @edsc.models.page) ->

  # Currently supported UMM-S Record Types
  supportedServiceTypes = ['OPeNDAP', 'ESI', 'ECHO ORDERS']

  colors = new ColorsModel()
  collectionColorPool = colors.collectionColorPool

  class ProjectCollection
    constructor: (@project, @collection, @meta={}) ->
      @collection.reference()
      @meta.color ?= collectionColorPool.next()

      @granuleAccessOptions = ko.asyncComputed({}, 100, @_loadGranuleAccessOptions, this)
      @serviceOptions       = new ServiceOptionsModel(@granuleAccessOptions)
      @isResetable          = ko.computed(@_computeIsResetable, this, deferEvaluation: true)
      @selectedVariables    = ko.observableArray([])
      @loadingServiceType   = ko.observable(false)
      @isCustomizable       = ko.observable(false)
      @editingAccessMethod  = ko.observable(false)
      @editingVariables     = ko.observable(false)
      @expectedUmmService   = ko.computed(@_computeExpectedUmmService, this, deferEvaluation: true)
      @isLoadingComplete    = ko.computed(@_computeIsLoadingComplete, this, deferEvaluation: true)
      @hasGranules          = ko.computed(@_computeHasGranules, this, deferEvaluation: true)
      @isReadyToDownload    = ko.computed(@_computeIsReadyToDownload, this, deferEvaluation: true)

      # When the loadingServiceType is updated re-calculate the subsetting flags
      @loadingServiceType.subscribe(@_computeSubsettingFlags)

      # Update the variableSubsettingEnabled flag when we modify the selectedVariables
      @selectedVariables.subscribe =>
        @variableSubsettingEnabled(@selectedVariables().length > 0)

      # Subsetting flags for the collection cards
      @spatialSubsettingEnabled        = ko.observable(false)
      @variableSubsettingEnabled       = ko.observable(false)
      @transformationSubsettingEnabled = ko.observable(false)
      @reformattingSubsettingEnabled   = ko.observable(false)
      @temporalSubsettingEnabled       = ko.observable(false)
      @selectedOutputFormat            = ko.observable(null)

      @selectedOutputFormat.subscribe =>
        @reformattingSubsettingEnabled(@selectedOutputFormat?)

      # Designate as a member of the current project
      @isProjectCollection  = @collection.isProjectCollection(true)

      # Re-calculate the subsetting flags when changes are made to an ECHO form
      $(document).on 'echoforms:modelchange', @_computeSubsettingFlags

    _computeIsResetable: ->
      if @granuleAccessOptions().defaults?
        for method in @granuleAccessOptions().defaults.accessMethod
          return true if method.collection_id == @collection.id
      false

    dispose: ->
      collectionColorPool.unuse(@meta.color) if collectionColorPool.has(@meta.color)
      @collection.dispose()
      @serviceOptions.dispose()

    _computeIsLoadingComplete: ->
      return true if !@loadingServiceType() && (@collection.total_size() == 'Not Provided' || @collection.total_size() && @collection.unit())
      false

    _loadGranuleAccessOptions: ->
      unless @granuleAccessOptions.peek()?
        dataSource = @collection.granuleDatasource()
        unless dataSource
          @granuleAccessOptions(hits: 0, methods: [])
          return

        @loadingServiceType(true)

        console.log "Loading granule access options for #{@collection.id}"

        $(document).trigger('dataaccessevent', [@collection.id])
        success = (data) =>
          console.log "Finished loading access options for #{@collection.id}"

          @granuleAccessOptions(data)

          # Done loading
          @loadingServiceType(false)
        retry = => @_loadGranuleAccessOptions

        dataSource.loadAccessOptions(success, retry)

    # Retrieve the user selected UMM Service from the access method. In the
    # future this will be set by the user, but for now were just going to
    # use the first supported UMM Service record as we'll only be assigning
    # one UMM Service record to each collection.
    _computeExpectedUmmService: =>
      expectedUmmService = null
      if @granuleAccessOptions()
        $.each @granuleAccessOptions().methods, (index, accessMethod) =>
          # For now we're using the first valid/supported UMM Service record found
          if accessMethod.umm_service?.umm?.Type in supportedServiceTypes
            expectedUmmService = accessMethod.umm_service

            # A non-false return statement within jQuery's `.each` will
            # simply continue rather than return, so we need to set a variable
            # to null outside of the loop, set the value like we've done above
            # when the conditional is true, and return false which will exit
            # the loop
            return false

      expectedUmmService

    triggerEditAccessMethod: =>
      @editingAccessMethod(true)

    triggerEditVariables: =>
      @editingVariables(true)

    showSpinner: (item, e) =>
      # This will likely need to change if we opt to support multiple access methods
      @serviceOptions?.accessMethod?()[0].showSpinner(item, e)
      @_computeSubsettingFlags()
      true

    findSelectedVariable: (variable) =>
      selectedVariablePosition = @indexOfSelectedVariable(variable)

      return null if selectedVariablePosition == -1

      @selectedVariables()[selectedVariablePosition]

    indexOfSelectedVariable: (variable) =>
      for selectedVariable, index in @selectedVariables()
        if variable.meta()['concept-id'] == selectedVariable.meta()['concept-id']
          return index
      -1

    hasSelectedVariable: (variable) =>
      @indexOfSelectedVariable(variable) != -1

    hasSelectedVariables: =>
      @selectedVariables().length > 0

    fromJson: (jsonObj) ->
      @serviceOptions.fromJson(jsonObj.serviceOptions)

    setSelectedVariablesById: (variables) =>
      # Retrieve the stored selected variables by concept id and assign
      # them to the project collection
      VariablesModel.forIds variables, {}, (variables) =>
        @selectedVariables(variables)

    customizeButtonText: =>
      return 'Edit Customizations' if @spatialSubsettingEnabled() || @variableSubsettingEnabled() || @transformationSubsettingEnabled() || @reformattingSubsettingEnabled()

      'Customize'

    selectedAccessMethod: =>
      if @serviceOptions.accessMethod().length > 0
        return @serviceOptions.accessMethod()[0].method()

    selectedAccessMethodType: =>
      if @serviceOptions.accessMethod().length > 0
        return @serviceOptions.accessMethod()[0].methodType()

    # When a user makes a changes to an ECHO form the accessMethods model
    # is updated so we'll need to parse the updated model to check for the
    # new values
    _accessMethodModelXml: =>
      if @serviceOptions.accessMethod().length > 0
        if @serviceOptions.accessMethod()[0].rawModel
          # Capybara-webkit does not seem to be able to parse/find tag namespaces so before
          # parsing the XML we replace namespace colons with a hyphen
          $($.parseXML(@serviceOptions.accessMethod()[0].rawModel.replace(/ecs\:/g, 'ecs-')))

    _findWithinAccessMethodModel: (path) =>
      xml = @_accessMethodModelXml()
      xml.find(path).text() if xml

    _computeSubsettingFlags: =>
      @_computeSpatialSubsettingEnabled()
      @_computeVariableSubsettingEnabled()
      @_computeTransformationSubsettingEnabled()
      @_computeReformattingSubsettingEnabled()
      @_computeTemporalSubsettingEnabled()

    _computeSpatialSubsettingEnabled: =>
      if @selectedAccessMethod()?.toLowerCase() == 'opendap'
        # For OPeNDAP collections we just pass along the spatial search params
        serializedObj = @project.serialized()

        hasBoundingBox = serializedObj.bounding_box?.length > 0
        hasPolygon     = serializedObj.polygon?.length > 0

        # Return true if any of the spatial subsettings exist
        @spatialSubsettingEnabled(hasBoundingBox || hasPolygon)
      else if @selectedAccessMethod()?.toLowerCase() == 'service'
          is_spatially_subset = @_findWithinAccessMethodModel('ecs-spatial_subset_flag')

          @spatialSubsettingEnabled(is_spatially_subset == "true")
      else
        @spatialSubsettingEnabled(false)

    _computeTemporalSubsettingEnabled: =>
      if @selectedAccessMethod()?.toLowerCase() == 'opendap'
        # OPeNDAP collections use a different means of calculating this value
      else if @selectedAccessMethod()?.toLowerCase() == 'service'
        is_temporally_subset = @_findWithinAccessMethodModel('ecs-temporal_subset_flag')

        @temporalSubsettingEnabled(is_temporally_subset == "true")
      else
        @temporalSubsettingEnabled(false)


    _computeVariableSubsettingEnabled: =>
      if @selectedAccessMethod()?.toLowerCase() == 'opendap'
        # OPeNDAP collections use a different means of calculating this value
      else if @selectedAccessMethod()?.toLowerCase() == 'service'
        formXml = @_accessMethodModelXml()

        if formXml
          # We don't know what the root is that would live within `SUBSET_DATA_LAYERS` but
          # when a value is selected it will live within `dataset` so we can check to see
          # if that element exists, if it does a value has been selected in the tree view
          has_variable_subsets = formXml.find('ecs-SUBSET_DATA_LAYERS').find('ecs-dataset').text()

          @variableSubsettingEnabled(has_variable_subsets.length > 0)
        else
          @variableSubsettingEnabled(false)
      else
        @variableSubsettingEnabled(false)

    _computeTransformationSubsettingEnabled: =>
      if @selectedAccessMethod()?.toLowerCase() == 'opendap'
        # OPeNDAP collections use a different means of calculating this value
      else if @selectedAccessMethod()?.toLowerCase() == 'service'
          has_transformation_subsets = $.trim(@_findWithinAccessMethodModel('ecs-PROJECTION'))

          # Check for the existense, a blank value, or the ESI equivelant of blank which is `&`
          @transformationSubsettingEnabled(has_transformation_subsets.length > 0 && has_transformation_subsets != '&')
      else
        @transformationSubsettingEnabled(false)

    _computeReformattingSubsettingEnabled: =>
      if @selectedAccessMethod()?.toLowerCase() == 'opendap'
        # OPeNDAP collections use a different means of calculating this value
        @selectedOutputFormat.valueHasMutated()
      else if @selectedAccessMethod()?.toLowerCase() == 'service'
          has_reformatting_subsets = $.trim(@_findWithinAccessMethodModel('ecs-FORMAT'))

          # Check for the existense, a blank value, or the ESI equivelant of blank which is `&`
          @reformattingSubsettingEnabled(has_reformatting_subsets.length > 0 && has_reformatting_subsets != '&')
      else
        @reformattingSubsettingEnabled(false)

    serialize: ->
      options = @serviceOptions.serialize()
      $(document).trigger('dataaccessevent', [@collection.id, options])

      form_hashes = []
      for method in @granuleAccessOptions().methods || []
        for accessMethod in options.accessMethod
          form_hash = {}
          if ((method.id == null || method.id == undefined ) || accessMethod.id == method.id) && accessMethod.type == method.type
            if method.id?
              form_hash['id'] = method.id
            else
              form_hash['id'] = accessMethod.type
            form_hash['form_hash'] = method.form_hash
            form_hashes.push form_hash

      id: @collection.id
      params: param(@collection.granuleDatasource()?.toQueryParams() ? @collection.query.globalParams())
      serviceOptions: options
      variables: @selectedVariables().map((v) => v.meta()['concept-id']).join('!')
      selectedService: @expectedUmmService(),
      form_hashes: form_hashes

    # Set the visible state for a collection's granules on the map.
    setVisibility: (visible) ->
      if typeof(visible) == 'boolean'
        @collection.visible(visible)
      return

    # Toggle the visible state for a collection's granules on the map.
    toggleVisibility: () ->
      @collection.visible(!@collection.visible())

    availableOutputFormats: () ->
      return false unless @selectedAccessMethodType() == 'opendap'

      formatMapping = {
        "NETCDF-3": "nc",
        "NETCDF-4": "nc4",
        "BINARY": "dods",
        "ASCII": "ascii"
      }

      supportedFormats = @expectedUmmService()?.umm?.ServiceOptions?.SupportedOutputFormats

      return false unless supportedFormats?

      formats = ({ 'name': format, 'value': formatMapping[format] } for format in supportedFormats when Object.keys(formatMapping).indexOf(format) != -1)

    _computeHasGranules: () ->
      @collection.granule_hits() > 0

    _computeIsReadyToDownload: () ->
      return true if @hasGranules() && @serviceOptions.readyToDownload()
      false

    projectIndex: () =>
      collections = @project.collections()
      [result] = ({collection, i} for collection, i in collections when collection.collection.id == @collection.id)
      result.i

    nextProjectCollectionId: () =>
      @project.collections()[@projectIndex() + 1]?.collection.id

    previousProjectCollectionId: () =>
      @project.collections()[@projectIndex() - 1]?.collection.id

  class Project
    constructor: (@query) ->
      @_collectionIds = ko.observableArray()
      @_collectionsById = {}

      @id = ko.observable(null)
      @collections = ko.computed(read: @getCollections, write: @setCollections, owner: this)
      @focusedProjectCollection = ko.observable(null)
      @focus = ko.computed(read: @_readFocus, write: @_writeFocus, owner: this)
      @searchGranulesCollection = ko.observable(null)
      @accessCollections = ko.computed(read: @_computeAccessCollections, owner: this, deferEvaluation: true)
      @allReadyToDownload = ko.computed(@_computeAllReadyToDownload, this, deferEvaluation: true)
      @allHaveAccessMethod = ko.computed(@_computeAllHaveAccessMethod, this, deferEvaluation: true)
      @allHaveGranules = ko.computed(@_computeAllHaveGranules, this, deferEvaluation: true)
      @visibleCollections = ko.computed(read: @_computeVisibleCollections, owner: this, deferEvaluation: true)
      @isLoadingComplete = ko.computed(read: @_computeIsLoadingComplete, this, deferEvaluation: true)

      @serialized = ko.computed
        read: @_toQuery
        write: @_fromQuery
        owner: this
        deferEvaluation: true
      @_pending = ko.observable(null)

    _computeIsLoadingComplete: ->
      if @collections?().length > 0
        for collection in @collections()
          if !collection.isLoadingComplete()
            return false
        true

    _computeAllReadyToDownload: ->
      return false if !@accessCollections().length
      return false for collection in @accessCollections() when !collection.hasGranules()
      return false for collection in @accessCollections() when !collection.serviceOptions.readyToDownload()
      true

    _computeAllHaveAccessMethod: ->
      return false if !@accessCollections().length
      return false for ds in @accessCollections() when !ds.selectedAccessMethod()
      true

    _computeAllHaveGranules: ->
      return false if !@accessCollections().length
      return false for ds in @accessCollections() when !ds.hasGranules()
      true

    _computeAccessCollections: ->
      @_collectionsById[id] for id in @_collectionIds()

    _readFocus: -> @focusedProjectCollection()
    _writeFocus: (collection) =>
      observable = @focusedProjectCollection
      current = observable()
      unless current?.collection == collection
        current?.dispose()
        if collection?
          projectCollection = new ProjectCollection(this, collection)
        observable(projectCollection)

    getCollections: ->
      @_collectionsById[id] for id in @_collectionIds()

    exceedCollectionLimit: ->
      for projectCollection in @getCollections()
        return true if projectCollection.collection.isMaxOrderSizeReached()
      false

    setCollections: (collections) =>
      collectionIds = []
      collectionsById = {}
      for ds, i in collections
        id = ds.id
        collectionIds.push(id)
        collectionsById[id] = @_collectionsById[id] ? new ProjectCollection(this, ds)
      @_collectionsById = collectionsById
      @_collectionIds(collectionIds)
      null

    _computeVisibleCollections: ->
      collections = (projectCollection.collection for projectCollection in @collections() when projectCollection.collection.visible())

      focus = @focus()?.collection

      if page.current.showFocusedCollections() && focus && focus.visible() && collections.indexOf(focus) == -1
        collections.push(focus)

      # Other visible collections not controlled by the project
      for collection in Collection.visible()
        collections.push(collection) if collections.indexOf(collection) == -1
      collections

    toggleActivePanel: (context) =>
      $('#' + context.collection.id + '_edit-options').trigger('toggle-panel')

    backToSearch: ->
      projectId = urlUtil.projectId()
      if projectId
        path = "/search?projectId=#{projectId}"
      else
        path = '/search?' + urlUtil.currentQuery()

      $(window).trigger('edsc.save_workspace')
      window.location.href = urlUtil.fullPath(path)

    # This seems like a UI concern, but really it's something that spans several
    # views and something we may eventually want to persist with the project or
    # allow the user to alter.
    colorForCollection: (collection) ->
      return null unless @hasCollection(collection)

      @_collectionsById[collection.id].meta.color

    isEmpty: () ->
      @_collectionIds.isEmpty()

    addCollection: (collection, callback) =>
      id = collection.id

      # If a collection already exists with this id, no need to proceed
      if !@_collectionsById[id]
        # If the focused collection is the collection being added, don't
        # instantiate a new object
        if @focus()?.collection?.id == id
          @_collectionsById[id] = @focus()
        else
          @_collectionsById[id] = new ProjectCollection(this, collection)

        @_collectionIds.remove(id)
        @_collectionIds.push(id)

      callback() if callback

    removeCollection: (collection) =>
      id = collection.id
      @_collectionsById[id]?.dispose()
      delete @_collectionsById[id]
      @_collectionIds.remove(id)
      null

    hasCollection: (other) =>
      @_collectionIds.indexOf(other.id) != -1

    isSearchingGranules: (collection) =>
      @searchGranulesCollection() == collection

    fromJson: (jsonObj) ->
      collections = null
      if jsonObj.collections?
        collections = {}
        collections[ds.id] = ds for ds in jsonObj.collections
      @_pendingAccess = collections
      @serialized(deparam(jsonObj.query))

    serialize: (collections=@collections) ->
      collections = (ds.serialize() for ds in @accessCollections())
      {query: param(@serialized()), collections: collections, source: urlUtil.realQuery()}

    # Retreive a ProjectCollection object for the collection matching the provided concept-id
    getProjectCollection: (id) ->
      focus = @focusedProjectCollection()
      if focus?.collection.id == id
        focus
      else
        @_collectionsById[id]

    _toQuery: ->
      return @_pending() if @_pending()?
      result = $.extend({}, @query.serialize())
      collections = [@focus()?.collection].concat(projectCollection.collection for projectCollection in @collections())
      ids = (ds?.id ? '' for ds in collections)
      if collections.length > 1 || collections[0]
        queries = [{}]
        result.p = ids.join('!')
        start = 1
        start = 0 if @focus()?.collection && !@hasCollection(@focus()?.collection)
        for collection, i in collections[start...]
          datasource = collection.granuleDatasource()
          projectCollection = @getProjectCollection(collection.id)
          query = {}

          # Only set the variables if there are any selected
          if projectCollection.hasSelectedVariables()
            query['variables'] = projectCollection.selectedVariables().map((v) => v.meta()['concept-id']).join('!')

          if datasource?
            $.extend(query, datasource.toBookmarkParams())

            queries[i + start] = {} if Object.keys(query).length == 0
            query.v = 't' if (i + start) != 0 && collection.visible()
            # Avoid inserting an empty map
            for own k, v of query
              queries[i + start] = query
              break

          if projectCollection.selectedOutputFormat()?
            query['output_format'] = projectCollection.selectedOutputFormat()

        for q, index in queries
          queries[index] = {} if q == undefined
        result.pg = queries if queries.length > 0

      result

    _fromQuery: (value) ->
      @query.fromJson(value)

      collectionIdStr = value.p
      if collectionIdStr
        if collectionIdStr != @_collectionIds().join('!')
          collectionIds = collectionIdStr.split('!')
          focused = !!collectionIds[0]
          collectionIds.shift() unless focused
          @_pending(value)
          value.pg ?= []
          value.pg[0] ?= {}

          # If the focused collection is also in the project copy its customizations to
          # the focused position, 0
          if focused
            for id, i in collectionIds
              if i > 0 && id == collectionIds[0]
                value.pg[0] = value.pg[i]

          CollectionsModel.forIds collectionIds, @query, (collections) =>
            @_pending(null)
            pending = @_pendingAccess ? {}

            # Default where we begin examining collections to 1 as position 0 is
            # reservered for the focused collection
            offset = 1

            # Update the offset if there is a focused collection
            offset = 0 if focused

            # `pg` holds the collection specific customizations that have been made
            queries = value["pg"] ? []

            # Iterate through the collections returned from `forIds` based on
            # the collection ids in the URL
            for collection, i in collections
              query = queries[i + offset]

              if i == 0 && focused
                # Set the focused collection if one exists
                @focus(collection)
              else
                # If this collection is the same as the focused collection
                # addCollection will look it up and use it to avoid redundant objects
                @addCollection(collection)

              # If customizations have been made to this collection they will exist in
              # the query object defined above
              if query?
                if query.variables
                  variables = query.variables.split('!')

                  # Retrieve the stored selected variables by concept id and assign
                  # them to the project collection
                  @getProjectCollection(collection.id).setSelectedVariablesById(variables)

                if collection.granuleDatasource()?
                  collection.granuleDatasource().fromBookmarkParams(query, value)

                  # Only look at the params for visibility on the project page
                  if page.current.page() == 'project'
                    collection.visible(true) if query.v == 't'

                if query.output_format
                  @getProjectCollection(collection.id).selectedOutputFormat(query.output_format)

              collection.dispose() # forIds ends up incrementing reference count
              @getProjectCollection(collection.id).fromJson(pending[collection.id]) if pending[collection.id]
            @_pendingAccess = null
      else
        @collections([])

  exports = Project
