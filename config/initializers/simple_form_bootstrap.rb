# frozen_string_literal: true

SimpleForm.setup do |config|
  config.button_class = 'btn'
  config.boolean_label_class = 'form-check-label'
  config.label_text = ->(label, required, _explicit_label) { "#{label} #{required}" }
  config.boolean_style = :inline
  config.item_wrapper_tag = :div
  config.include_default_input_wrapper_class = false
  config.error_notification_class = 'alert alert-danger'
  config.error_method = :to_sentence
  config.input_field_error_class = 'is-invalid'
  config.input_field_valid_class = 'is-valid'

  # vertical forms
  config.wrappers :vertical_form, class: 'mb-3' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: 'form-label fw-bold'
    b.use :input, class: 'form-control', error_class: 'is-invalid', valid_class: 'is-valid'
    b.use :full_error, wrap_with: { class: 'invalid-feedback' }
    b.use :hint, wrap_with: { class: 'form-text' }
  end

  # vertical input for boolean
  config.wrappers :vertical_boolean, tag: 'fieldset', class: 'mb-3' do |b|
    b.use :html5
    b.optional :readonly
    b.wrapper :form_check_wrapper, class: 'form-check' do |bb|
      bb.use :input, class: 'form-check-input', error_class: 'is-invalid', valid_class: 'is-valid'
      bb.use :label, class: 'form-check-label'
      bb.use :full_error, wrap_with: { class: 'invalid-feedback' }
      bb.use :hint, wrap_with: { class: 'form-text' }
    end
  end

  # vertical input for radio buttons and check boxes
  config.wrappers :vertical_collection, item_wrapper_class: 'form-check', item_label_class: 'form-check-label',
                                        tag: 'fieldset', class: 'mb-3' do |b|
    b.use :html5
    b.optional :readonly
    b.wrapper :legend_tag, tag: 'legend', class: 'col-form-label pt-0 fw-bold' do |ba|
      ba.use :label_text
    end
    b.use :input, class: 'form-check-input', error_class: 'is-invalid', valid_class: 'is-valid'
    b.use :full_error, wrap_with: { class: 'invalid-feedback d-block' }
    b.use :hint, wrap_with: { class: 'form-text' }
  end

  # Floating Labels form
  config.wrappers :floating_labels_form, class: 'form-floating mb-3' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :input, class: 'form-control', error_class: 'is-invalid', valid_class: 'is-valid'
    b.use :label
    b.use :full_error, wrap_with: { class: 'invalid-feedback' }
    b.use :hint, wrap_with: { class: 'form-text' }
  end

  config.default_wrapper = :vertical_form
  config.wrapper_mappings = {
    boolean: :vertical_boolean,
    check_boxes: :vertical_collection,
    file: :vertical_form,
    radio_buttons: :vertical_collection,
    select: :vertical_form
  }
end
