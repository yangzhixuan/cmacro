(in-package :cl-user)
(defpackage cmacro
  (:use :cl :anaphora)
  (:export :main))
(in-package :cmacro)

(defun extract-and-macroexpand (data)
  (destructuring-bind (ast macros) 
      (cmacro.macro:extract-macro-definitions (cmacro.parse:parse-data data))
    (cmacro.macro:macroexpand-ast ast macros)))

(defun macroexpand-data (data)
  (cmacro.parse:print-ast (extract-and-macroexpand data)))

(defun macroexpand-pathname (pathname)
  (macroexpand-data (cmacro.preprocess::slurp-file pathname)))

(defun get-opt (args boolean options)
  (first
   (remove-if #'null
              (mapcar #'(lambda (opt)
                          (aif (member opt args :test #'equal)
                               (if boolean
                                   (first it)
                                   (second it))))
                      options))))

(defun get-binary-opt (args &rest options)
  (get-opt args t options))

(defun get-opt-value (args &rest options)
  (get-opt args nil options))

(defun files (args binary-options)
  (flet ((optp (option)
           (and (>= (length option) 1)
                (char= (elt option 0) #\-))))
    (remove-if #'null
               (loop for sub-args on args collecting
                 (if (optp (first sub-args))
                     ;; Skip
                     (progn
                       (unless (member (first sub-args)
                                       binary-options
                                       :test #'equal)
                         (setf sub-args (rest sub-args)))
                       nil)
                     ;; It's a file
                     (first sub-args))))))

(defparameter +help+ 
"Usage: cmc [file]* [option]*

  -o, --output    Path to the output file
  -l,--lex        Dump the tokens (Without macroexpanding)
  -n,--no-expand  Don't macroexpand, but remove macro definitions
  -h,--help       Print this text")

(defun process-file (pathname lexp)
  (cond
    (lexp
     ;; Just lex the file
     (format nil "~{~A~%~}"
             (cmacro.preprocess:process-pathname pathname)))
    (t
     (macroexpand-pathname pathname)))) 

(defun main (args)
  (let ((files       (mapcar #'parse-namestring
                             (files (cdr args)
                                    '("-l" "--lex"))))
        (output-file (get-opt-value args "-o" "--output"))
        (lexp        (get-binary-opt args "-l" "--lex"))
        (helpp       (get-binary-opt args "-h" "--help")))
    (when helpp
      (format t "~A~%" +help+)
      (sb-ext:quit))
    (unless files
      (error 'cmacro.error:no-input-files))
    (if output-file
        ;; Write to a file
        (with-open-file (stream
                         output-file
                         :direction :output
                         :if-does-not-exist :create
                         :if-exists :supersede)
          (loop for file in files do
            (write-string (process-file file lexp)
                          stream)))
        ;; Write to stdout
        (progn
          (loop for file in files do
            (write-string (process-file file lexp)))
          (terpri)))))
