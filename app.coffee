express = require 'express'
request = require 'request'
fs = require 'fs'
url = require 'url'
IMGR = require('imgr').IMGR

app = express()

imgr = new IMGR({ gm_quality: 90 })

app.get '/image/:size/:imgUrl', (req, res) ->
  imgUrl = req.params.imgUrl
  rawSize = req.params.size
  imgSize = rawSize.split('x')

  # bail if not the right size..
  if (rawSize isnt '160x237' and rawSize isnt '320x474')
    res.status(403).send('Invalid size..')
    console.log '** attempt was made to resize image with invalid size:', req.originalUrl
    return

  # console.log 'resize:', imgSize

  inDir = 'img_input/'
  outDir = 'img_output/'
  filename = url.parse(imgUrl).pathname.split('/').pop()
  filename = filename.replace(/(.*)(\.[^\.]*)$/, "$1-" + rawSize + "$2")

  inputPath = inDir + filename
  outputPath = outDir + filename

  writeStream = fs.createWriteStream inputPath
  writeStream.on('finish', ->
    console.log '>> file downloaded:', filename
    imgr.load(inputPath).adaptiveResize(imgSize[0], imgSize[1]).save outputPath, (err) ->
      if err then err
      console.log '>> file resized:', outputPath
      fs.unlink inputPath, (err) ->
        if err then throw err
      fs.createReadStream(outputPath).pipe(res)
  )

  console.log '>> requesting file from:', imgUrl
  request
    .get(imgUrl)
    .on('error', ->
      console.log '** error requesting file from', imgUrl
    )
    .pipe(writeStream)

app.get '/img/:img', (req, res, next) ->
  imgFile = req.params.img
  if ((/nomovie.jpg|nomovie@2x.jpg/).test(imgFile) is false)
    next()
    return
  fs.createReadStream('img/' + imgFile).pipe(res)

# catch 404 and forward to error handler
app.use (req, res, next)->
  err = new Error 'Not Found'
  err.status = 404
  # next err
  res.status(404).send('404')

# production error handler no stacktraces leaked to user
# app.use (err, req, res, next)->
#   res.status(err.status || 500)
#   res.render 'error', {
#     message: err.message,
#     error: {}
#   }

app.set 'port', process.env.PORT || 9000

server = app.listen app.get('port'), () ->
  console.log 'express server listening on port ' + server.address().port