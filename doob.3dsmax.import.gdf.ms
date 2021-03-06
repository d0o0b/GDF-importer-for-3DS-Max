/******************************************************************************************************

    GDF importer for 3DS Max
    Fileformat by WAMIT ( http://www.wamit.com )

******************************************************************************************************

    Author:             Tom Molvik ( git @ doob.no )

    Discription:        Importer was based on filespecs @ http://www.wamit.com/manualv7.1/wamit_v7manualch7.html#x9-600007.4
                        There is no support for advanced features.

                        Basic steps:
                        --------------
                        1. ReadFile:            Fileunits are in meters.
                                                For every point in file, apply systemunits-correction.
                                                For every 4 points read, build 2 triangles.
                        2. BuildMesh:           Mesh is created based on a vertex-array and a triangle-array.
                        3. CleanupMesh:         WeldVertsByThreshold "0,001m"
                        4. ModifyMesh:          Mirror

******************************************************************************************************
    Sample from a .GDF-file:
******************************************************************************************************	

WAMIT Geometry Date file generated by GeoCutHydrostat, 15-Aug-2013 --  1:51:43.272 PM
     1.00000      9.80665  ULEN, Grav
           0            1  ISX, ISY
        3900               nPanC
    1.18304900E+02     0.00000000E+00    -2.00000000E-05
    1.18303500E+02     0.00000000E+00    -2.54640000E-01
    1.18244000E+02     3.36800000E-01    -2.66850000E-01
    1.18244900E+02     3.36800000E-01    -2.00000000E-05
    ...

******************************************************************************************************/

struct doob_3dsmax_import_gdf_struct
(
    PUBLIC

        fn MeshFromFile gdfFileName:( getOpenFileName caption:"doob_GDF.MeshFromFile(): Select a .GDF-file..." filename:""	 types:"GDF Files (*.gdf)|*.gdf|" ) weldTreshhold:"0,001m" =
        (
            try
            (
                local vert_array = #()
                local face_array = #()

                format "doob_GDF.MeshFromFile gdfFile: %\n" gdfFileName


            --------------------------------------------------------
            --	ReadFile
            --------------------------------------------------------
                gdfFile = openFile gdfFileName mode:"r"
                if gdfFile != undefined then
                (
                --------------------------------------------------------
                --	Get number of verts expected to read from file
                --------------------------------------------------------
                    local num_verts = 0
                    local num_faces = 0

                    local count = 0
                    while not eof gdfFile do
                    (
                        ln = readLine gdfFile
                        if ln.count > 20 then
                            num_verts += 1
                    )


                --------------------------------------------------------
                --	HEADER
                --------------------------------------------------------
                    seek gdfFile 0                                            --	Reset fileposition

                    --------------------------------------------------------
                    --	WAMIT Geometry Date file generated by GeoCutHydrostat, 15-Aug-2013 --  1:51:43.272 PM
                    --------------------------------------------------------
                    hl = readLine gdfFile
                    local h = filterString hl " \t,"
                    if NOT (h[1] == @"WAMIT" and h[2] == @"Geometry") then
                    (
                        throw "ERROR: Not a .GDF file."
                    )

                    --------------------------------------------------------
                    --	     1.00000      9.80665  ULEN, Grav
                    --------------------------------------------------------
                    hl = readLine gdfFile
                    local h = filterString hl " \t,"
                    if NOT (h[3] == @"ULEN" and h[4] == @"Grav") then
                    (
                        throw "ERROR: Failed to find ULEN, Grav"
                    )

                    ULEN 	= h[1] as float
                    GRAV  	= h[2] as float

                    format "\tULEN: %\n" ULEN
                    format "\tGRAV: %\n" GRAV

                    --------------------------------------------------------
                    --           0            1  ISX, ISY
                    --------------------------------------------------------
                    hl = readLine gdfFile
                    local h = filterString hl " \t,"
                    if NOT (h[3] == @"ISX" and h[4] == @"ISY") then
                    (
                        throw "ERROR: Failed to find ISX, ISY"
                    )

                    ISX 	= h[1] as integer
                    ISY  	= h[2] as integer

                    format "\tISX: %\n" ISX
                    format "\tISY: %\n" ISY

                    --------------------------------------------------------
                    --        3900               nPanC
                    --------------------------------------------------------
                    hl = readLine gdfFile
                    local h = filterString hl " \t,"
                    if NOT (h[2] == @"nPanC") then
                    (
                        throw "ERROR: Failed to find nPanC"
                    )

                    nPanC 	= h[1] as integer

                    format "\tnPanC: %\n" nPanC


                    num_verts -= 4		-- Skip lines in header
                --------------------------------------------------------
                --	BODY
                --------------------------------------------------------
                    vert_array.count = num_verts
                    face_array.count = (num_verts / 2)

                    format "\tnum_verts: %\n" vert_array.count
                    format "\tnum_faces: %\n" face_array.count

                    local f = 0
                    local m1 = units.decodeValue "1,0m"                            -- Get 1 meter in systemunits
                    for v = 1 to num_verts do
                    (
                        ln = readLine gdfFile
                        local l = filterString ln " \t"

                        local p3 = [0, 0, 0]

                        p3.x = l[1] as float
                        p3.y = l[2] as float
                        p3.z = l[3] as float

                        vert_array[v] = p3 * m1                                    -- Apply Meter-scaling pre.save to array

                        --------------------------------------------------------
                        --	Build triangles data
                        --------------------------------------------------------
                        if (mod v 4) == 0 then
                        (
                            f += 1
                            face_array[f] = [v-3, v-2, v-1]

                            f += 1
                            face_array[f] = [v-3, v-1, v]
                        )
                    )
                    close gdfFile

                    --------------------------------------------------------
                    --	BuildMesh
                    --------------------------------------------------------
                    new_mesh = mesh name:(uniquename "doob_GDF_") vertices:vert_array faces:face_array

                    --------------------------------------------------------
                    --	CleanupMesh
                    --------------------------------------------------------
                    meshop.weldVertsByThreshold new_mesh #{1..new_mesh.numverts} (units.decodeValue weldTreshhold)

                    --------------------------------------------------------
                    --	MeshMirror
                    --------------------------------------------------------
                    if validModifier new_mesh Mirror then
                    (
                        if ISX == 1 then
                        (
                            mirX = Mirror()
                            mirX.name = "Mirror_X"
                            mirX.mirror_axis = 0
                            mirX.copy = True

                            addModifier new_mesh mirX
                        )

                        if ISY == 1 then
                        (
                            mirY = Mirror()
                            mirY.name = "Mirror_Y"
                            mirY.mirror_axis = 1
                            mirY.copy = True

                            addModifier new_mesh mirY
                        )
                    )
                )

                --------------------------------------------------------
                --	Success
                --------------------------------------------------------
                format "\tCreated Mesh: %\n" new_mesh.name
                Return new_mesh
            ) catch ( )

            --------------------------------------------------------
            --	Failed
            --------------------------------------------------------
            format "\tMesh was not created\n"
            Return False

        ),

        on create do
        (
            format "Struct Created: %\n" this
        )
)

::doob_GDF = doob_3dsmax_import_gdf_struct()                --  Init a global variable
::doob_GDF.MeshFromFile()                                   --  Force getOpenFileName-GUI to popup
