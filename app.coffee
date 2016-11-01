express = require 'express'
request = require 'request'
fs = require 'fs'
path = require 'path'
url = require 'url'
AWS = require 'aws-sdk'
IMGR = require('imgr').IMGR
gm = require('gm').subClass(imageMagick: true)
smartcrop = require('smartcrop-gm')

region = 'sg'

AWS.config.region = 'ap-southeast-1'
s3 = new AWS.S3 { params: { Bucket: 'scsearchimages' }}

app = express()

imgr = new IMGR({ gm_quality: 90, orientation: 1, crop_offset: 8 })

app.get '/poster/:size/:imgUrl', (req, res) ->
  imgUrl = req.params.imgUrl
  rawSize = req.params.size
  outDir = './img_output/'

  filename = url.parse(imgUrl).pathname.split('/').pop()
  filename = filename.replace(/(.*)(\.[^\.]*)$/, "$1-" + rawSize + "$2")

  imgFile = outDir + filename

  fs.stat imgFile, (err, stats) ->
    if (err)
      if (rawSize is '320x474')
        fs.createReadStream('./img/nomovie@2x.jpg').pipe(res)
      else
        fs.createReadStream('./img/nomovie.jpg').pipe(res)
    else
      fs.createReadStream(imgFile).pipe(res)

### --------------------------------------------------------------------------------------------------
# For regular images..
###
app.get '/image/:size/:imgUrl', (req, res) ->
  imgUrl = req.params.imgUrl
  rawSize = req.params.size
  imgSize = rawSize.split('x')

  # bail if not the right size..
  # if (rawSize isnt '160x237' and rawSize isnt '320x474')
  #   res.status(403).send('Invalid size..')
  #   console.log '** attempt was made to resize image with invalid size:', req.originalUrl
  #   return

  # console.log 'resize:', imgSize

  inDir = './img_input/'
  outDir = './img_output/'
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

      fs.createReadStream(outputPath)
        .on('error', ->
          console.error 'File couldn\'t be downloaded. Too many redirects?'
          res.status(400).send('File couldn\'t be downloaded. Too many redirects?')
        )
        .pipe(res)
  )

  console.log '>> requesting file from:', imgUrl

  request({ url: imgUrl, followRedirect: true, followAllRedirects: true })
    .on('response', (response) ->
      console.log '>> statusCode:', response.statusCode
    )
    .on('error', ->
      console.log '** error requesting file from', imgUrl
    )
    .pipe(writeStream)

### --------------------------------------------------------------------------------------------------
# Using smartcrop..
###
app.get '/smartcrop/:size/:imgUrl', (req, res) ->
  imgUrl = req.params.imgUrl
  rawSize = req.params.size
  imgSize = rawSize.split('x')

  # bail if not the right size..
  # if (rawSize isnt '160x237' and rawSize isnt '320x474')
  #   res.status(403).send('Invalid size..')
  #   console.log '** attempt was made to resize image with invalid size:', req.originalUrl
  #   return

  # console.log 'resize:', imgSize

  inDir = './img_input/'
  outDir = './img_output/'
  filename = url.parse(imgUrl).pathname.split('/').pop()
  filename = filename.replace(/(.*)(\.[^\.]*)$/, "$1-" + rawSize + "-smartcrop$2")

  inputPath = inDir + filename
  outputPath = outDir + filename

  console.log '>> starting smartcrop image for:', imgUrl
  request imgUrl, { encoding: null }, (err, response, body) ->
    if err
      console.error err
      res.status(400).send('Something went wrong when requesting the image..')
      return

    smartcrop.crop(body,{ width: imgSize[0], height: imgSize[1] }).then (result) ->
      crop = result.topCrop
      gm(body).crop(crop.width, crop.height, crop.x, crop.y).resize(imgSize[0], imgSize[1]).write outputPath, (error) ->
        if error
          console.error error
          res.status(400).send('Something went wrong when cropping the image..')
        else
          console.log('>> done creating smartcrop image..')
          fs.createReadStream(outputPath)
            .on('error', ->
              console.error 'Something went wrong while streaming image out..'
              res.status(400).send('Something went wrong while streaming image out..')
            )
            .pipe(res)

### --------------------------------------------------------------------------------------------------
# This is for SCB..
###
app.get '/sc/:size/:country/:imgUrl', (req, res) ->
  imgUrl = req.params.imgUrl
  rawSize = req.params.size
  imgSize = rawSize.split('x')
  country = req.params.country

  # bail if not the right size..
  if (rawSize isnt '375x175' and rawSize isnt '750x350')
    res.status(403).send('Invalid size..')
    console.log '** attempt was made to resize image with invalid size:', req.originalUrl
    return

  # console.log 'resize:', imgSize

  inDir = 'sc_input/'
  outDir = 'sc_output/'
  filename = url.parse(imgUrl).pathname.split('/').pop()
  filename = filename.replace(/(.*)(\.[^\.]*)$/, "$1-" + rawSize + "$2")

  inputPath = inDir + filename
  outputPath = outDir + filename

  writeStream = fs.createWriteStream inputPath

  writeStream.on 'finish', ->
    console.log '>> file downloaded:', filename
    imgr.load(inputPath).crop(750, 350, 688, 0).adaptiveResize(imgSize[0], imgSize[1]).save outputPath, (err) ->
      if err then err
      console.log '>> file resized:', outputPath

      fs.unlink inputPath, (err) ->
        if err then throw err
      
      # check if file exists..
      fs.stat outputPath, (err, stats) ->
        if err and err.code is 'ENOENT'
          res.status(404).end('404')
        else
          # fs.createReadStream(outputPath).pipe(res)
          sendToS3 outputPath, country, (err, data) ->
            if err then throw err
            res.send data

  console.log '>> requesting file from:', imgUrl
  request
    .get(imgUrl)
    .on('error', ->
      console.log '** error requesting file from', imgUrl
      res.status(404).end('404')
    )
    .pipe(writeStream)

app.get '/img/:img', (req, res, next) ->
  imgFile = req.params.img
  if ((/nomovie.jpg|nomovie@2x.jpg/).test(imgFile) is false)
    next()
    return
  fs.createReadStream('img/' + imgFile).pipe(res)

# http://blog.katworksgames.com/2014/01/26/nodejs-deploying-files-to-aws-s3/
sendToS3 = (file, country, cb) ->
  basefile = file.substr file.lastIndexOf("/") + 1
  fs.readFile file, (err, data) ->
    if err
      cb err
    else
      s3.upload { Body: data, Key: country + '/search/images/' + basefile, ACL: 'public-read', ContentType: 'image/jpg' }, (err, res) ->
        if err
          cb err
        else
          console.log 'done:', res
          # res.send res
          cb null, res

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