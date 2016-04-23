Spine        = require "spine"
Relations    = require "spine-relations/async"
Cradle       = require "cradle"
errify       = require "errify"


capitalize = (str) -> str[0].toUpperCase() + str[1..]


class Couch extends Spine.Model
  @setup: (server) ->
    server.secure    ?= /https/.exec server.host
    server.port      ?= if server.secure then 443 else 80
    server.cache     ?= true
    server.cacheSize ?= 500
    server.timeout   ?= 10000

    conn = new Cradle.Connection server
    @db = conn.database server.database
    @attributes.push "type"

  @parseRow: (row) ->
    {doc} = row
    doc.id or= doc._id
    doc

  @makeRecords: (rows) ->
    docs = (@parseRow row for row in rows)
    @refresh docs

  @find: (id, cb = ->) ->
    ideally = errify cb

    await @db.get id, ideally defer records
    [record] = @refresh records
    cb null, record

  @findAll: (options = {}, cb = ->) ->
    (cb = options) and options = {} if typeof options is "function"
    ideally = errify cb
    options.include_docs ?= true

    await @db.all options, ideally defer rows
    cb null, @makeRecords rows

  @findMany: (ids, cb = ->) ->
    ideally = errify cb

    await @db.get ids, ideally defer rows
    cb null, @makeRecords rows

  @findAllByAttribute: (key, value, options = {}, cb = ->) ->
    (cb = options) and options = {} if typeof options is "function"
    ideally = errify cb

    name   = "findAllBy#{capitalize key}"
    method = @[name]
    return callback new Error "@#{name} not implemented" unless method?
    await method value, options, ideally defer rows
    cb null, @makeRecords rows

  @findAllById: (key, value, options, cb = ->) ->
    return @findMany value, cb if Array.isArray value
    @find value, cb

  type: -> @constructor.className

  attributes: (hideId) ->
    result = super()
    delete result.id if hideId
    result

  save: (cb = ->) ->
    ideally = errify cb
    wasNew  = @isNew()
    changed = @diff() unless wasNew
    {id}    = this

    if wasNew
      @[key] = value for key, value of @constructor.defaults when not @[key]?
      await @constructor.db.save id, (@attributes true), ideally defer result
    else if changed
      await @constructor.db.merge id, changed, ideally defer result

    super()
    cb null, this

  remove: (cb = ->) ->
    ideally = errify cb

    await @constructor.db.remove @id, @_rev, ideally defer res
    super()
    cb()


module.exports = Couch
