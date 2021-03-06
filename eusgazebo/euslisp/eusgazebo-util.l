;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; urdf & gazebo util

;; convert model
(defun irteus2urdf-for-gazebo
  (model
   &key
   (name (send model :name))
   (collada-dir "/tmp")
   (urdf-dir nil)
   (static nil))

  (cond
   ((not (subclassp (class model) cascaded-link))
    (format t "invalid class, not childclass of cascaded-link~%"))
   ((null (send model :links)) (format t "please setq links~%"))
   (t
    ;; convert to collada
    (collada::eus2collada model collada-dir)
    ;; convert to urdf
    (let* ((collada-path (format nil "~a/~a.dae" collada-dir (send model :name))))
      (cond
       ((probe-file collada-path)
	(format t "generate ~A.dae~%convert to urdf~%" name)
	;; convert to urdf model
	(unix:system
	 (format nil
		 "rosrun eusgazebo eus2urdf_for_gazebo.py ~a ~a ~a"
		 name collada-path (if urdf-dir urdf-dir "")))
	;; make static model
        (when static
          (unix:system
           (format nil
                   "rosrun eusgazebo make_urdf_static_model_for_gazebo.py ~a ~a"
                   name (if urdf-dir urdf-dir ""))))
	)
       (t (format nil "dae error~%"))))
    (format nil "~a/~a~a/~a" urdf-dir name (if static "_static" "") "model.urdf")
    )))


;; spawn model
(defun spawn-model-to-gazebo
  (urdf-model-path
   &key
   (model-name nil)
   (model-coords (make-coords)))

  (let* ((model-pos (scale 0.001 (send model-coords :pos)))
	 (model-rpy (car (send model-coords :rpy-angle)))
	 (x (elt model-pos 0))
	 (y (elt model-pos 1))
	 (z (elt model-pos 2))
	 (roll (elt model-rpy 2))
	 (pitch (elt model-rpy 1))
	 (yaw (elt model-rpy 0)))
    (unix:system (format nil "gzfactory spawn -f ~a -x ~a -y ~a -z ~a -R ~a -P ~a -Y ~a ~a"
			 urdf-model-path x y z roll pitch yaw (if model-name (format nil "-m ~a" model-name) ""))))
  )

;; delete model
(defun delete-model-to-gazebo
  (model-name)

  (unix:system (format nil "gzfactory delete -m ~a" model-name))
  )


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ros data conversion util

(defun pose->coords
  (msg)

  (let* ((pos (scale 1000 (ros-xyz->eus-vec (send msg :position))))
	 (quat (ros-xyzw->eus-vec (send msg :orientation)))
	 (rot (quaternion2matrix quat)))
    (make-coords :pos pos :rot rot)))

(defun ros-xyz->eus-vec
  (msg)

  (float-vector (send msg :x) (send msg :y) (send msg :z)))

(defun ros-xyzw->eus-vec
  (msg)

  (float-vector (send msg :w) (send msg :x) (send msg :y) (send msg :z)))

(defun coords->pose
  (coords)

  (let* ((pose (instance geometry_msgs::Pose :init))
	 (pos (scale 0.001 (send coords :worldpos)))
	 (rot (send coords :worldrot))
	 (quat (matrix2quaternion rot)))
    (send pose :position :x (elt pos 0))
    (send pose :position :y (elt pos 1))
    (send pose :position :z (elt pos 2))
    (send pose :orientation :x (elt quat 1))
    (send pose :orientation :y (elt quat 2))
    (send pose :orientation :z (elt quat 3))
    (send pose :orientation :w (elt quat 0))
    pose))
