#--------------------------------------------------------------------------
# Software:     InVesalius - Software de Reconstrucao 3D de Imagens Medicas
# Copyright:    (C) 2001  Centro de Pesquisas Renato Archer
# Homepage:     http://www.softwarepublico.gov.br
# Contact:      invesalius@cti.gov.br
# License:      GNU - GPL 2 (LICENSE.txt/LICENCA.txt)
#--------------------------------------------------------------------------
#    Este programa e software livre; voce pode redistribui-lo e/ou
#    modifica-lo sob os termos da Licenca Publica Geral GNU, conforme
#    publicada pela Free Software Foundation; de acordo com a versao 2
#    da Licenca.
#
#    Este programa eh distribuido na expectativa de ser util, mas SEM
#    QUALQUER GARANTIA; sem mesmo a garantia implicita de
#    COMERCIALIZACAO ou de ADEQUACAO A QUALQUER PROPOSITO EM
#    PARTICULAR. Consulte a Licenca Publica Geral GNU para obter mais
#    detalhes.
#--------------------------------------------------------------------------

import numpy as np

import invesalius.session as ses
import invesalius.project as prj
from invesalius.pubsub import pub as Publisher


class Image:
    def __init__(self):
        self.LoadState()

    @property
    def fiducials(self):
        return prj.Project().image_fiducials

    def SaveState(self):
        pass
        # state = {
        #     'image_fiducials': self.fiducials.tolist(),
        # }
        # session = ses.Session()
        # session.SetState('image', state)

    def LoadState(self):
        pass
        # session = ses.Session()
        # state = session.GetState('image')
        # if state is not None:
        #     self.fiducials = np.array(state['image_fiducials'])

    def SetImageFiducial(self, fiducial_index, position):
        self.fiducials[fiducial_index, :] = position
        print("Image fiducial {} set to coordinates {}".format(fiducial_index, position))
        ses.Session().ChangeProject()
        self.SaveState()

    def GetImageFiducials(self):
        return self.fiducials
    
    def ResetImageFiducials(self):
        prj.Project().image_fiducials = np.full([3, 3], np.nan)
        ses.Session().ChangeProject()
        Publisher.sendMessage("Reset image fiducials")
        self.SaveState()

    def GetImageFiducialForUI(self, fiducial_index, coordinate):
        value = self.fiducials[fiducial_index, coordinate]
        if np.isnan(value):
            value = 0

        return value

    def AreImageFiducialsSet(self):
        return not np.isnan(self.fiducials).any()

    def IsImageFiducialSet(self, fiducial_index):
        return not np.isnan(self.fiducials)[fiducial_index].any()
