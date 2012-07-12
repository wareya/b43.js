'use strict'
WIDTH = 800
HEIGHT = 600
MAP_SCALE = 6
DEBUG = false
map = {}
currentmap = 'atalia'

# different image storage format between entities and maps
# probably change later to accomodate maps with several frames or layers & remove minor code duping

images =
    maps:
        atalia:
            bg:
                urls: ['media/maps/ctf_atalia_bg.png']
                data: []
            wm:
                urls: ['media/maps/ctf_atalia_wm.png']
                data: []
    entities:
        char:
            quote:
                urls: [
                    'media/entities/char/querly_red_0.png'
                    'media/entities/char/querly_red_1.png'
                ]
                data: []


preloadImages = []

for key in Object.getOwnPropertyNames images.entities.char # Always preload all chars, weapons, and projectiles
    preloadImages.push images.entities.char[key]
    
for key in Object.getOwnPropertyNames images.maps.atalia  #  T E M P O R A R Y  preload
    preloadImages.push images.maps.atalia[key]
    
console.log preloadImages

globalContext = null
camX = 0
camY = 0
camFocus = null
entities = []

# JavaScript augmentation

Math.sign = (num) ->
    num >= 0 ? 1 : -1

# Core

class Sprite
    constructor: (frames, centerX, centerY, bBox) ->
        @frames = frames
        @centerX = centerX || 0
        @centerY = centerY || 0
        # left, right, top, bottom
        @bBox = bBox || [0, frames[0].width, 0, frames[0].height]

    draw: (x, y, frameNum) ->
        globalContext.drawImage @frames[frameNum], x - @centerX, y - @centerY
        if DEBUG
            globalContext.strokeStyle = 'black'
            globalContext.strokeWidth = 0.5
            globalContext.strokeRect(
                Math.floor(x + @bBox[0] - @centerX),
                Math.floor(y + @bBox[2] - @centerY),
                Math.floor(@bBox[1] - @bBox[0]),
                Math.floor(@bBox[3] - @bBox[2])
            )
            globalContext.strokeStyle = 'red'
            globalContext.strokeWidth = 0.5
            globalContext.strokeRect(
                Math.floor(x + @bBox[0]),
                Math.floor(y + @bBox[2]),
                Math.floor(@bBox[1] - @bBox[0]),
                Math.floor(@bBox[3] - @bBox[2])
            )

    collidesPoint: (x, y) ->
        return (@bBox[0] - @centerX <= x and x < @bBox[1] - @centerX and @bBox[2] - @centerY <= y and y < @bBox[3] - @centerY)

    collidesSprite: (sprite, x, y) ->
        bb = sprite.bBox
        return (@collidesPoint(bb[0] + x, bb[2] + y) or @collidesPoint(bb[1] + x, bb[2] + y) or @collidesPoint(bb[1] + x, bb[3] + y) or @collidesPoint(bb[0] + x, bb[3] + y))

    collidesMap: (x, y) ->
        xOffset = x - @centerX
        yOffset = y - @centerY
        globalContext.fillStyle = 'black'
        for _x in [@bBox[0]...@bBox[1]]
            for _y in [@bBox[2]...@bBox[3]]
                if not wmPlaceFree _x + xOffset, _y + yOffset
                    return true
        return false

class Entity
    constructor: () ->
        @x = 0
        @y = 0
        @hSpeed = 0
        @vSpeed = 0
        @sprite = null
        @frameNum = 0
        @collides = false

    onDraw: () ->
        if @sprite != null
            @sprite.draw(Math.floor(@x), Math.floor(@y), @frameNum)

    onStep: () ->
        @x += @hSpeed
        @y += @vSpeed

    onCollision: () ->
        null

onCollision = () ->
    for entity in entities
        if entity.collides
            if entity.sprite.collidesMap(entity.x, entity.y)
                entity.onCollision()
            # other entity collision
            for entity2 in entities
                if entity2 != entity
                    if entity.sprite.collidesSprite(entity2.sprite, entity2.x - entity.x, entity2.y - entity.y)
                        entity.onCollision(entity2)

onStep = () ->
    for entity in entities
        entity.onStep()

onDraw = () ->
    globalContext.fillStyle = 'black'
    globalContext.fillRect 0, 0, WIDTH, HEIGHT

    globalContext.save()
    globalContext.translate -Math.floor(camX), -Math.floor(camY) 

    globalContext.drawImage map.bg, 0, 0 
    if DEBUG
        for x in [0...map.width]
            for y in [0...map.height]
                if map.wm[x][y]
                    globalContext.fillRect x * MAP_SCALE, y * MAP_SCALE, MAP_SCALE, MAP_SCALE

    globalContext.restore()

    for entity in entities
        globalContext.save()
        globalContext.translate -camX, -camY

        entity.onDraw()

        globalContext.restore()

    globalContext.textStyle = '12pt Arial'
    globalContext.fillText 'suck dis pygg2', 0, 10 

onTick = () ->
    onCollision()
    onStep()
    if camFocus != null
        camX = camFocus.x - camFocus.sprite.centerX - WIDTH / 2
        camY = camFocus.y - camFocus.sprite.centerY - HEIGHT / 2
    onDraw()

nnScale = (img, ctx, scale) ->
    tx = document.createElement 'canvas'
    [tx.width, tx.height] = [img.width, img.height]
    tx = tx.getContext '2d'
    tx.drawImage img, 0, 0
    imgData = tx.getImageData(0, 0, img.width, img.height).data
    for x in [0...img.width]
        for y in [0...img.height]
            i = (y * img.width + x) * 4
            [r, g, b, a] = [imgData[i], imgData[i + 1], imgData[i + 2], imgData[i + 3]]
            ctx.fillStyle = 'rgba(' + r + ',' + g + ',' + b + ',' + (a / 255) + ')'
            ctx.fillRect x * scale, y * scale, scale, scale

preScale = (img, scale) ->
    cv = document.createElement 'canvas'
    cv.width = img.width * scale
    cv.height = img.height * scale
    ctx = cv.getContext '2d'
    nnScale img, ctx, scale
    return cv

decodeWM = (wm) ->
    canvas = document.createElement 'canvas'
    [canvas.width, canvas.height] = [wm.width, wm.height]
    
    ctx = canvas.getContext '2d'
    ctx.drawImage wm, 0, 0
    data = ctx.getImageData(0, 0, wm.width, wm.height).data
    
    # find bottom-left pixel
    i = ((wm.height - 1) * wm.width) * 4
    r = data[i]
    g = data[i + 1]
    b = data[i + 2]
    a = data[i + 3]

    # decode to true/false values
    rows = []
    
    for x in [0...wm.width]
        col = []
        for y in [0...wm.height]
            i = (y * wm.width + x) * 4
            result = !(data[i] == r and data[i + 1] == g and data[i + 2] == b and data[i + 3] == a)
            col.push result
        rows.push col
    return rows

wmPlaceFree = (x, y) ->
    x = Math.floor x / MAP_SCALE
    y = Math.floor y / MAP_SCALE
    if x >= 0 && x < map.width * MAP_SCALE && y >= 0 && y < map.height * MAP_SCALE
        return !(map.wm[x][y])
    return false

loadImages = (onDone) ->
    numdone = 0
    console.log 'Loading images...'
    loadImage = (url) ->
        img = document.createElement 'img'
        img.src = url
        console.log 'Loading image: ' + img.src
        img.onload = () ->
            numdone += 1
            images[url] = img
            if numdone == preloadImages.length
                console.log 'Loaded ' + numdone + ' images'
                onDone()
        img.onerror = () ->
            loadImage url
    
    loadFrames = (graphic) ->
        for url in graphic.urls
            graphic.data.push loadImage url
    
    for graphic in preloadImages
        loadFrames graphic

window.onload = () ->
    loadImages () ->
        canvas = document.createElement('canvas')
        [canvas.width, canvas.height] = [WIDTH, HEIGHT]

        document.body.appendChild canvas
        globalContext = canvas.getContext '2d'
        
        map.bg = images.maps[currentmap].bg.data[0]
        console.log map.bg
        console.log images.entities.char.quote.data[0] ## HELP ajf, these end up being (function () {"use strict";return loadImage(url);}) AND I DON'T KNOW WHY ;-;
        [map.width, map.height] = [map.bg.width, map.bg.height]
        map.bg = preScale(map.bg, MAP_SCALE)

        map.wm = decodeWM(images.maps[currentmap].wm.data[0])

        camFocus = new QuerlyRed()
        camFocus.x = map.bg.width / 2
        camFocus.y = 15
        entities.push camFocus

        otherQuot = new QuerlyRed()
        otherQuot.x = camFocus.x + 25
        otherQuot.y = 15
        entities.push otherQuot

        window.setInterval onTick, 1000 / 30

# Game Elements

class Character extends Entity
    constructor: () ->
        super()
        @collides = true

    onStep: () ->
        super()
        if wmPlaceFree @x, @y + 1
            @vSpeed += 1
        if Math.abs @vSpeed > 5
            @vSpeed = Math.sign(@vSpeed) * 5

    onCollision: (entity) ->
        if entity?
            console.log 'Collision at ' + @x + ', ' + @y + ' with entity pos ' + entity.x + ', ' + entity.y
        @vSpeed = @hSpeed = 0

class QuerlyRed extends Character
    constructor: () ->
        super()
        image = images.entities.char.quote
        frames = image.data[i]
        @sprite = new Sprite frames, 16, 20, [9, 23, 7, 31]
        @frameNum = 0
