# Requires
_ = require 'underscore'
moment = require('moment')
moment.lang('en')

# Define the Configuration
docpadConfig = {
    # ...
    templateData:
        site:
            title: "ADThomsen"

        getPreparedTitle: -> if @document.title then "#{@document.title} | #{@site.title}" else @site.title

        formatDate: (date,format='YYYY') -> moment(date).format(format)

        _: _

    collections:
        pages: -> 
            @getCollection("html").findAllLive({inMenu:true},[{order:1}]).on "add", (model) ->
                model.setMetaDefaults({layout:"default"})
        posts: ->
            @getCollection("documents").findAllLive({isPost:true},[{date:-1}]).on "add", (model) ->
                model.setMetaDefaults({relativeOutDirPath: 'posts'})

    # ...
}

# Export the Configuration
module.exports = docpadConfig