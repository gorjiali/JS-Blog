$(document).ready(function() {
  $('.editArticle-form').on('submit', async function(e) {
    e.preventDefault();
    const id = $('button').attr('id');
    const form = new FormData();
    form.append('title', document.getElementById('title').value);
    form.append('context', document.getElementById('context').value);
    if (document.getElementById('imageCover').files[0] !== undefined) {
      form.append('imageCover', document.getElementById('imageCover').files[0]);
    }
    axios({
      method: 'PATCH',
      url: `/api/articles/${id}`,
      data: form
    })
      .then(function(response) {
        if (response.data.status === 'success!!') {
          showAlert('success', 'Article updated successfully!');
          window.setTimeout(() => {
            location.assign('/myArticles');
          }, 1500);
        }
      })
      .catch(err => {
        if (err.response.data.message.name === 'ValidationError') {
          let errorMsg = err.response.data.message.message.split(': ');
          showAlert('error', errorMsg[2]);
        } else if (err.response.data.message.code === 11000) {
          showAlert(
            'error',
            `This ${
              Object.keys(err.response.data.message.keyValue)[0]
            } already exist! Please choose another one.`
          );
        }
      });
  });
});
