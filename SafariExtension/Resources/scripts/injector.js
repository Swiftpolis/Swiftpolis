if (typeof BrowserNameSpace === "undefined") {
    if (typeof browser !== 'undefined')
        BrowserNameSpace = browser;
    else if (typeof chrome !== 'undefined')
        BrowserNameSpace = chrome;
}

function injectPdmModal(){
    const html = `
<div id="pdm-modal-holder" class="pdm-modal-holder-hide">
    <div id="pdm-modal" role="dialog" aria-label="Choose links for Swiftpolis">
        <div class="pdm-header">
            <div class="pdm-logo">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12M7 10.5l5 5 5-5M4 20.5h16"/></svg>
            </div>
            <div>
                <span class="pdm-title">Choose links</span>
                <span class="pdm-subtitle">They'll be sent to Swiftpolis</span>
            </div>
        </div>
        <div class="pdm-inputs">
            <select id="pdm_include_or_exclude" class="pdm-select" aria-label="Keep or leave out">
                <option value="include">Keep</option>
                <option value="exclude">Leave out</option>
            </select>
            <input placeholder="links containing..." type="text" id="pdm_text" class="pdm-input">
            <select id="pdm_include_extension" class="pdm-select" aria-label="File type"></select>
        </div>
        <div id="pdm-preview-links"></div>
        <div class="pdm-actions">
            <pdminput id="pdm_cancel_modal">Cancel</pdminput>
            <pdminput id="pdm_captuare_links">Download <pdmlinkcount id="pdm-link-count"></pdmlinkcount></pdminput>
        </div>
    </div>
</div>`;

    document.body.insertAdjacentHTML('beforeend', html);

}

function showPdmModal(extensions) {
    const modalHolder = document.getElementById('pdm-modal-holder');
    const modal = document.getElementById('pdm-modal');
    setTimeout( ()=> modal.classList.add("pdm-animate-down"),
        100);
    modalHolder.classList.remove('pdm-modal-holder-hide');
    const includeSelectOption = document.getElementById("pdm_include_extension");
    let options = `<option value="no_extension">Any type</option>`;
    for( let k of Object.keys(extensions)){
        options+=`<option value="${PdmSanitizeHTML(k)}">${PdmSanitizeHTML(k)}</option>`;
    }
    includeSelectOption.innerHTML = options;
}

function PdmSanitizeHTML(str) {
    var temp = document.createElement('div');
    temp.textContent = str;
    return temp.innerHTML;
}
function removePdmModal() {
    document.getElementById("pdm-modal-holder").remove();
}
function getFileNameFromUrl(link) {
    let possibleFileName = link.split('/').pop().split('#')[0].split('?')[0].trim();
    try{
        return decodeURIComponent(possibleFileName);
    }catch (e) {
        return possibleFileName;
    }
}
function getExtensionOfUrl(link) {
    const tempFileName = getFileNameFromUrl(link);
    let filename = tempFileName === "" ? link : tempFileName ;
    const dotPos = filename.lastIndexOf(".");
    if(dotPos===-1)
        return "";
    filename = filename.substr(dotPos+1, 4);

    return !filename.match(/^([0-9a-z]+)$/i) || !isNaN(filename) ? "" : filename;
}

function sendPickedLinks(msg) {
    BrowserNameSpace.runtime.sendMessage({
        type:"getSelected",
        message: msg
    });
}
function dismissModal(links, success) {
    if(success)
        sendPickedLinks(links);
    removePdmModal();

}
function shortcutHandler(event, onSucess, onFail){
    if (event.code === "Enter") {
        onSucess()
    } else if (event.code === "Escape") {
        onFail()
    }
}
injectPdmModal();
